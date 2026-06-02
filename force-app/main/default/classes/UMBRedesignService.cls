/**
 * UMBRedesignService
 * Powers the "Redesign" button. A design (UMB_Design_Option__c) is made of element
 * slots (UMB_Design_Element__c), each holding a REAL Product2 from the design's tier
 * (final_package_tier__c) and category (category__c).
 *
 * Redesign keeps every hearted element and re-rolls the rest: a different product from
 * the same tier + category, and a different placement. Then it re-renders the image
 * (Gemini) and recomputes the price from the real catalog (standard Pricebook).
 *
 * No fake products or prices — everything comes from Product2 / PricebookEntry.
 */
public with sharing class UMBRedesignService {

    // Slots filled per design and how many of each. Skipped silently if the tier has no
    // ai-render-eligible products in that category.
    private static final Map<String, Integer> SLOTS = new Map<String, Integer>{
        'Hardscape' => 1,
        'Outdoor Living' => 1,
        'Planting' => 2,
        'Lighting' => 1
    };

    private static final Map<String, List<String>> PLACEMENTS = new Map<String, List<String>>{
        'Hardscape' => new List<String>{
            'as a patio directly off the back of the house',
            'as a patio centered in the yard',
            'as a patio in the rear corner with a walkway' },
        'Outdoor Living' => new List<String>{
            'along the rear fence', 'at the edge of the patio', 'in the back-left corner' },
        'Planting' => new List<String>{
            'along the left property line', 'along the rear fence for privacy',
            'flanking the patio', 'in the back-right corner' },
        'Lighting' => new List<String>{
            'lining the walkway and patio', 'around the patio perimeter' }
    };

    // ── Heart toggle ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void toggleHeart(Id elementId, Boolean hearted) {
        UMB_Design_Element__c el = [SELECT Id, Is_Hearted__c FROM UMB_Design_Element__c WHERE Id = :elementId LIMIT 1];
        el.Is_Hearted__c = hearted;
        update el;
    }

    // ── Redesign ─────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void redesign(Id designOptionId) {
        if (designOptionId == null) throw new AuraHandledException('No design provided.');
        System.enqueueJob(new RedesignJob(designOptionId));
    }

    public class RedesignJob implements Queueable, Database.AllowsCallouts {
        private Id designOptionId;
        public RedesignJob(Id designOptionId) { this.designOptionId = designOptionId; }

        public void execute(QueueableContext ctx) {
            // ---- Phase 0: queries + in-memory selection (no DML, no callout yet) ----
            UMB_Design_Option__c opt = [
                SELECT Id, Tier__c, Opportunity__c FROM UMB_Design_Option__c WHERE Id = :designOptionId LIMIT 1
            ];
            String tier = opt.Tier__c;
            Id oppId = opt.Opportunity__c;

            List<UMB_Design_Element__c> existing = [
                SELECT Id, Category__c, Is_Hearted__c, Product__c, Product__r.Name, Placement__c, Unit_Price__c
                FROM UMB_Design_Element__c WHERE Design_Option__c = :designOptionId
            ];
            List<UMB_Design_Element__c> hearted = new List<UMB_Design_Element__c>();
            List<UMB_Design_Element__c> toDelete = new List<UMB_Design_Element__c>();
            Map<String, Integer> heartedByCat = new Map<String, Integer>();
            for (UMB_Design_Element__c e : existing) {
                if (e.Is_Hearted__c) {
                    hearted.add(e);
                    Integer c = heartedByCat.containsKey(e.Category__c) ? heartedByCat.get(e.Category__c) : 0;
                    heartedByCat.put(e.Category__c, c + 1);
                } else {
                    toDelete.add(e);
                }
            }

            // Product pool for this tier, grouped by category.
            Map<String, List<Product2>> pool = new Map<String, List<Product2>>();
            for (Product2 p : [
                SELECT Id, Name, category__c FROM Product2
                WHERE final_package_tier__c = :tier AND ai_render_eligible__c = true
                AND category__c IN :SLOTS.keySet()
            ]) {
                if (!pool.containsKey(p.category__c)) pool.put(p.category__c, new List<Product2>());
                pool.get(p.category__c).add(p);
            }

            // Build the new (non-hearted) element picks in memory.
            Set<Id> heartedProductIds = new Set<Id>();
            for (UMB_Design_Element__c e : hearted) heartedProductIds.add(e.Product__c);

            List<UMB_Design_Element__c> newElements = new List<UMB_Design_Element__c>();
            Set<Id> usedProductIds = new Set<Id>(heartedProductIds);
            for (String cat : SLOTS.keySet()) {
                Integer target = SLOTS.get(cat);
                Integer alreadyHearted = heartedByCat.containsKey(cat) ? heartedByCat.get(cat) : 0;
                Integer need = target - alreadyHearted;
                List<Product2> catPool = pool.get(cat);
                if (need <= 0 || catPool == null || catPool.isEmpty()) continue;
                for (Integer i = 0; i < need; i++) {
                    Product2 pick = pickProduct(catPool, usedProductIds);
                    if (pick == null) break;
                    usedProductIds.add(pick.Id);
                    newElements.add(new UMB_Design_Element__c(
                        Design_Option__c = designOptionId,
                        Product__c = pick.Id,
                        Category__c = cat,
                        Name = pick.Name.left(80),
                        Placement__c = pickPlacement(cat)
                    ));
                }
            }

            // Prices from the standard Pricebook for everything in the new design.
            Set<Id> allProductIds = new Set<Id>(usedProductIds);
            Map<Id, Decimal> priceByProduct = new Map<Id, Decimal>();
            Set<Id> standardPriced = new Set<Id>();
            if (!allProductIds.isEmpty()) {
                for (PricebookEntry pe : [
                    SELECT Product2Id, UnitPrice, Pricebook2.IsStandard FROM PricebookEntry
                    WHERE Product2Id IN :allProductIds AND IsActive = true
                ]) {
                    // Prefer the standard-pricebook price; fall back to any active entry.
                    if (!priceByProduct.containsKey(pe.Product2Id) || (pe.Pricebook2.IsStandard && !standardPriced.contains(pe.Product2Id))) {
                        priceByProduct.put(pe.Product2Id, pe.UnitPrice);
                        if (pe.Pricebook2.IsStandard) standardPriced.add(pe.Product2Id);
                    }
                }
            }
            for (UMB_Design_Element__c e : newElements) {
                e.Unit_Price__c = priceByProduct.containsKey(e.Product__c) ? priceByProduct.get(e.Product__c) : 0;
            }

            // Prompt naming the real products + placements.
            String basePhoto = UMBDesignGenerationService.getLatestBackyardPhoto(oppId);
            String prompt = buildPrompt(tier, hearted, newElements, String.isNotBlank(basePhoto));

            // ---- Phase 1: callout ----
            String image = UMBDesignGenerationService.callGemini(prompt, basePhoto);

            // ---- Phase 2: DML ----
            if (!toDelete.isEmpty()) delete toDelete;
            if (!newElements.isEmpty()) insert newElements;

            Decimal total = 0;
            for (UMB_Design_Element__c e : hearted) total += (e.Unit_Price__c == null ? 0 : e.Unit_Price__c);
            for (UMB_Design_Element__c e : newElements) total += (e.Unit_Price__c == null ? 0 : e.Unit_Price__c);

            opt.Price__c = total;
            opt.Is_Concept__c = String.isBlank(basePhoto);
            if (String.isNotBlank(image)) {
                opt.Rendered_Image_URL__c = UMBDesignGenerationService.saveRendering(oppId, tier, image);
            }
            update opt;
        }
    }

    // ── Selection helpers (Math.random is allowed in Apex) ───────────────────────

    private static Product2 pickProduct(List<Product2> catPool, Set<Id> exclude) {
        List<Product2> available = new List<Product2>();
        for (Product2 p : catPool) if (!exclude.contains(p.Id)) available.add(p);
        if (available.isEmpty()) available = catPool; // allow repeat if pool exhausted
        if (available.isEmpty()) return null;
        Integer idx = Math.min(available.size() - 1, (Integer) (Math.random() * available.size()));
        return available[idx];
    }

    private static String pickPlacement(String cat) {
        List<String> opts = PLACEMENTS.get(cat);
        if (opts == null || opts.isEmpty()) return '';
        Integer idx = Math.min(opts.size() - 1, (Integer) (Math.random() * opts.size()));
        return opts[idx];
    }

    @TestVisible
    private static String buildPrompt(String tier, List<UMB_Design_Element__c> hearted,
                                      List<UMB_Design_Element__c> fresh, Boolean hasPhoto) {
        List<String> lines = new List<String>();
        for (UMB_Design_Element__c e : hearted) lines.add(e.Product__r.Name + ' ' + e.Placement__c);
        for (UMB_Design_Element__c e : fresh) lines.add(e.Name + ' ' + e.Placement__c);
        String items = String.join(lines, '; ');
        String base = hasPhoto
            ? 'Photorealistically edit this backyard photo. Keep the house, fence, and trees exactly. Add: '
            : 'Generate a photorealistic concept of a backyard for the ' + tier + ' package featuring: ';
        return base + items + '. Cohesive, professional landscape design.';
    }
}