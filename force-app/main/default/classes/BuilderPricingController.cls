/**
 * BuilderPricingController
 *
 * AuraEnabled controller for the divisionPricingPanel LWC.
 * Manages Builder_Pricing_Book__c and Builder_Pricing_Line__c records
 * for a given Account (Division or Parent).
 */
public with sharing class BuilderPricingController {

    // ─────────────────────────────────────────────────────────────────────────
    // DTOs
    // ─────────────────────────────────────────────────────────────────────────

    public class PricingBookDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  status;
        @AuraEnabled public String  effectiveDate;
        @AuraEnabled public String  expirationDate;
        @AuraEnabled public String  notes;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public List<PricingLineDTO> lines;
    }

    public class PricingLineDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  itemDescription;
        @AuraEnabled public String  bmgPackageCode;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String  unit;
        @AuraEnabled public String  effectiveDate;
        @AuraEnabled public String  expirationDate;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // READ
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<PricingBookDTO> getPricingBooks(Id accountId) {
        if (accountId == null) return new List<PricingBookDTO>();

        List<Builder_Pricing_Book__c> books = [
            SELECT Id, Name, Status__c, Effective_Date__c, Expiration_Date__c, Notes__c,
                   (SELECT Id, Item_Description__c, BMG_Package_Code__c, Unit_Price__c,
                           Unit__c, Effective_Date__c, Expiration_Date__c
                    FROM   Pricing_Lines__r
                    ORDER BY Item_Description__c)
            FROM   Builder_Pricing_Book__c
            WHERE  Builder_Account__c = :accountId
            ORDER BY Status__c, Name
        ];

        List<PricingBookDTO> result = new List<PricingBookDTO>();
        for (Builder_Pricing_Book__c book : books) {
            result.add(toBookDTO(book));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static PricingBookDTO getActiveBook(Id accountId) {
        if (accountId == null) return null;
        List<Builder_Pricing_Book__c> books = [
            SELECT Id, Name, Status__c, Effective_Date__c, Expiration_Date__c, Notes__c,
                   (SELECT Id, Item_Description__c, BMG_Package_Code__c, Unit_Price__c,
                           Unit__c, Effective_Date__c, Expiration_Date__c
                    FROM   Pricing_Lines__r
                    ORDER BY Item_Description__c)
            FROM   Builder_Pricing_Book__c
            WHERE  Builder_Account__c = :accountId
            AND    Status__c = 'Active'
            LIMIT  1
        ];
        return books.isEmpty() ? null : toBookDTO(books[0]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WRITE
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static String createPricingBook(Id accountId, String bookName, String effectiveDate) {
        if (accountId == null) throw new AuraHandledException('Account ID is required.');
        if (String.isBlank(bookName)) throw new AuraHandledException('Book name is required.');

        Builder_Pricing_Book__c book = new Builder_Pricing_Book__c(
            Name                = bookName,
            Builder_Account__c  = accountId,
            Status__c           = 'Draft',
            Effective_Date__c   = String.isBlank(effectiveDate) ? Date.today()
                                        : Date.valueOf(effectiveDate)
        );

        try {
            insert book;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return book.Id;
    }

    @AuraEnabled
    public static void activatePricingBook(Id bookId) {
        if (bookId == null) throw new AuraHandledException('Book ID is required.');
        Builder_Pricing_Book__c book = new Builder_Pricing_Book__c(
            Id        = bookId,
            Status__c = 'Active'
        );
        try {
            update book;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    @AuraEnabled
    public static void deactivatePricingBook(Id bookId) {
        if (bookId == null) throw new AuraHandledException('Book ID is required.');
        Builder_Pricing_Book__c book = new Builder_Pricing_Book__c(
            Id        = bookId,
            Status__c = 'Inactive'
        );
        try {
            update book;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    @AuraEnabled
    public static String savePricingLine(Id bookId, String lineId, String itemDescription,
                                          String bmgCode, Decimal unitPrice, String unit,
                                          String effectiveDate) {
        if (bookId == null) throw new AuraHandledException('Pricing Book ID is required.');
        if (String.isBlank(itemDescription)) throw new AuraHandledException('Item description is required.');

        Builder_Pricing_Line__c line;
        if (String.isBlank(lineId)) {
            line = new Builder_Pricing_Line__c(Builder_Pricing_Book__c = bookId);
        } else {
            line = new Builder_Pricing_Line__c(Id = lineId);
        }

        line.Item_Description__c  = itemDescription;
        line.BMG_Package_Code__c  = bmgCode;
        line.Unit_Price__c        = unitPrice;
        line.Unit__c              = unit;
        if (!String.isBlank(effectiveDate)) {
            line.Effective_Date__c = Date.valueOf(effectiveDate);
        }

        try {
            upsert line;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return line.Id;
    }

    @AuraEnabled
    public static void deletePricingLine(Id lineId) {
        if (lineId == null) throw new AuraHandledException('Line ID is required.');
        try {
            delete new Builder_Pricing_Line__c(Id = lineId);
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    @AuraEnabled
    public static void saveBulkLines(Id bookId, List<Map<String, Object>> rows) {
        if (bookId == null) throw new AuraHandledException('Book ID is required.');
        if (rows == null || rows.isEmpty()) return;

        List<Builder_Pricing_Line__c> toUpsert = new List<Builder_Pricing_Line__c>();
        for (Map<String, Object> r : rows) {
            Builder_Pricing_Line__c line = new Builder_Pricing_Line__c(
                Builder_Pricing_Book__c = bookId,
                Item_Description__c     = (String)  r.get('itemDescription'),
                BMG_Package_Code__c     = (String)  r.get('bmgCode'),
                Unit__c                 = (String)  r.get('unit')
            );
            Object rawId = r.get('id');
            if (rawId != null && !String.isBlank((String) rawId)) {
                line.Id = (Id) rawId;
            }
            Object rawPrice = r.get('unitPrice');
            if (rawPrice != null) {
                line.Unit_Price__c = Decimal.valueOf(String.valueOf(rawPrice));
            }
            toUpsert.add(line);
        }

        try {
            upsert toUpsert;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static PricingBookDTO toBookDTO(Builder_Pricing_Book__c book) {
        PricingBookDTO dto   = new PricingBookDTO();
        dto.id               = book.Id;
        dto.name             = book.Name;
        dto.status           = book.Status__c;
        dto.effectiveDate    = book.Effective_Date__c != null ? String.valueOf(book.Effective_Date__c) : null;
        dto.expirationDate   = book.Expiration_Date__c != null ? String.valueOf(book.Expiration_Date__c) : null;
        dto.notes            = book.Notes__c;
        dto.isActive         = 'Active'.equals(book.Status__c);
        dto.lines            = new List<PricingLineDTO>();

        if (book.Pricing_Lines__r != null) {
            for (Builder_Pricing_Line__c line : book.Pricing_Lines__r) {
                PricingLineDTO ld = new PricingLineDTO();
                ld.id              = line.Id;
                ld.itemDescription = line.Item_Description__c;
                ld.bmgPackageCode  = line.BMG_Package_Code__c;
                ld.unitPrice       = line.Unit_Price__c;
                ld.unit            = line.Unit__c;
                ld.effectiveDate   = line.Effective_Date__c != null ? String.valueOf(line.Effective_Date__c) : null;
                ld.expirationDate  = line.Expiration_Date__c != null ? String.valueOf(line.Expiration_Date__c) : null;
                dto.lines.add(ld);
            }
        }
        return dto;
    }
}