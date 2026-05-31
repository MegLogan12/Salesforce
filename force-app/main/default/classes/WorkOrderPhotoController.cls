/**
 * WorkOrderPhotoController
 * Handles Photo__c record creation from the lovingAddPhoto LWC quick action.
 * Supports two paths:
 *   1. lightning-file-upload: ContentDocument is already attached; we just create the Photo__c record.
 *   2. Camera capture: base64 data arrives; we create ContentVersion + ContentDocumentLink + Photo__c.
 */
public without sharing class WorkOrderPhotoController {

    /**
     * Called after lightning-file-upload finishes.
     * The file is already uploaded as a ContentDocument linked to the Work Order.
     * We create a Photo__c record pointing back to it.
     */
    @AuraEnabled
    public static void createPhotoRecord(
        Id workOrderId,
        Id contentDocumentId,
        String photoType,
        String notes
    ) {
        try {
            // Fetch the ContentDocument URL and name
            ContentDocument cd = [
                SELECT Id, Title, LatestPublishedVersionId
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                LIMIT 1
            ];

            // Build the Photo__c record.
            // Note: Photo__c.Work_Order__c references standard WorkOrder (not custom Work_Order__c),
            // so we do NOT set it here. The ContentDocumentLink to the Work_Order__c record
            // provides the linkage. workOrderId is stored via CDL only.
            Photo__c photo = new Photo__c(
                Photo_Type__c     = photoType,
                Notes__c          = notes,
                Taken_At__c       = Datetime.now(),
                Portal_Visible__c = false
            );
            insert photo;

            // Link the ContentDocument to the Photo record as well
            ContentDocumentLink link = new ContentDocumentLink(
                LinkedEntityId   = photo.Id,
                ContentDocumentId = contentDocumentId,
                ShareType        = 'V',
                Visibility       = 'AllUsers'
            );
            insert link;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('createPhotoRecord failed: ' + e.getMessage());
        }
    }

    /**
     * Called when the user captures a photo using the device camera.
     * Receives base64-encoded image data, creates a ContentVersion (file),
     * then creates a Photo__c record linked to the Work Order.
     */
    @AuraEnabled
    public static void uploadCameraPhoto(
        Id workOrderId,
        String base64Data,
        String fileName,
        String mimeType,
        String photoType,
        String notes
    ) {
        try {
            if (String.isBlank(base64Data)) {
                throw new AuraHandledException('No image data received.');
            }

            // Create ContentVersion (this auto-creates ContentDocument)
            ContentVersion cv = new ContentVersion(
                Title           = (String.isNotBlank(fileName) ? fileName : 'photo_' + System.now().getTime()),
                PathOnClient    = (String.isNotBlank(fileName) ? fileName : 'photo.jpg'),
                VersionData     = EncodingUtil.base64Decode(base64Data),
                IsMajorVersion  = true
            );
            insert cv;

            // Get the ContentDocument Id
            Id contentDocId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ].ContentDocumentId;

            // Link to Work Order
            ContentDocumentLink woLink = new ContentDocumentLink(
                LinkedEntityId    = workOrderId,
                ContentDocumentId = contentDocId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            );
            insert woLink;

            // Create Photo__c record (Work_Order__c not set — it references standard WorkOrder;
            // linkage to custom Work_Order__c is via ContentDocumentLink on workOrderId)
            Photo__c photo = new Photo__c(
                Photo_Type__c     = photoType,
                Notes__c          = notes,
                Taken_At__c       = Datetime.now(),
                Portal_Visible__c = false
            );
            insert photo;

            // Link ContentDocument to Photo record
            ContentDocumentLink photoLink = new ContentDocumentLink(
                LinkedEntityId    = photo.Id,
                ContentDocumentId = contentDocId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            );
            insert photoLink;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('uploadCameraPhoto failed: ' + e.getMessage());
        }
    }

    /**
     * Returns photos for a given Work Order (used by workOrderPhotoGallery LWC).
     */
    /**
     * Returns photos for a given Work Order.
     * Since Photo__c.Work_Order__c references STANDARD WorkOrder, we find photos
     * via ContentDocumentLink: WO record → ContentDocument → Photo__c records
     * that are also linked to those same ContentDocuments.
     */
    @AuraEnabled(cacheable=true)
    public static List<PhotoDto> getPhotos(Id workOrderId) {
        List<PhotoDto> out = new List<PhotoDto>();
        if (workOrderId == null) return out;

        // Get all ContentDocuments linked to this Work Order record
        Set<Id> cdIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :workOrderId LIMIT 500
        ]) { cdIds.add(cdl.ContentDocumentId); }

        if (cdIds.isEmpty()) return out;

        // Find Photo__c records also linked to those ContentDocuments
        Set<Id> photoIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId FROM ContentDocumentLink
            WHERE ContentDocumentId IN :cdIds
            AND LinkedEntityId != :workOrderId LIMIT 500
        ]) { photoIds.add(cdl.LinkedEntityId); }

        if (photoIds.isEmpty()) return out;

        // Query Photo__c records
        String objType = 'Photo__c';
        if (!Schema.getGlobalDescribe().containsKey(objType)) return out;

        for (Photo__c p : [
            SELECT Id, Name, Photo_Type__c, S3_URL__c, Notes__c,
                   Taken_At__c, Portal_Visible__c
            FROM Photo__c
            WHERE Id IN :photoIds
            ORDER BY Taken_At__c DESC NULLS LAST
            LIMIT 200
        ]) {
            PhotoDto d = new PhotoDto();
            d.id = p.Id;
            d.photoType = p.Photo_Type__c;
            d.s3Url = p.S3_URL__c;
            d.notes = p.Notes__c;
            d.takenAt = p.Taken_At__c != null ? p.Taken_At__c.format('MM/dd/yyyy h:mm a') : '';
            d.portalVisible = p.Portal_Visible__c;
            out.add(d);
        }
        return out;
    }

    public class PhotoDto {
        @AuraEnabled public String  id;
        @AuraEnabled public String  photoType;
        @AuraEnabled public String  s3Url;
        @AuraEnabled public String  notes;
        @AuraEnabled public String  takenAt;
        @AuraEnabled public String  takenBy;
        @AuraEnabled public Boolean portalVisible;
    }
}