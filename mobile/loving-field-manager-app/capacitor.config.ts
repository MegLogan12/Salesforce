import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.loving.fieldmanager",
  appName: "LOVING Field Manager",
  webDir: "dist",
  bundledWebRuntime: false,
  ios: {
    contentInset: "automatic"
  }
};

export default config;
