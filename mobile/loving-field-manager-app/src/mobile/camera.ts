import type { PhotoProof } from "../types";

export async function captureFieldPhoto(category: string): Promise<PhotoProof> {
  try {
    const { Camera, CameraResultType, CameraSource } = await import("@capacitor/camera");
    const image = await Camera.getPhoto({
      resultType: CameraResultType.DataUrl,
      source: CameraSource.Camera,
      quality: 80,
      saveToGallery: false,
      promptLabelHeader: "LOVING Field Photo",
      promptLabelPhoto: "Take Photo",
      promptLabelPicture: "Use Camera"
    });
    return { category, caption: "Mobile camera upload", status: "complete", uri: image.dataUrl };
  } catch {
    return { category, caption: "Camera unavailable. Use desktop upload fallback.", status: "issue" };
  }
}
