import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Platform } from 'react-native';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useFrameworkReady } from '@/hooks/useFrameworkReady';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,
      retry: 1,
    },
  },
});

function WebStyleReset() {
  if (Platform.OS !== 'web') return null;
  return (
    <style
      dangerouslySetInnerHTML={{
        __html:
          'input:focus,textarea:focus{outline:none!important}body{background:#F3F3F3;font-family:"SF Pro Text","Helvetica Neue","Segoe UI",Roboto,Arial,sans-serif}',
      }}
    />
  );
}

export default function RootLayout() {
  useFrameworkReady();

  return (
    <QueryClientProvider client={queryClient}>
      <WebStyleReset />
      <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: '#F3F3F3' } }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="+not-found" />
      </Stack>
      <StatusBar style="light" />
    </QueryClientProvider>
  );
}
