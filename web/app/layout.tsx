import type { Metadata } from "next";
import { JetBrains_Mono } from "next/font/google";
import "./styles.css";

const jetBrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains",
  weight: ["400", "500", "600"]
});

export const metadata: Metadata = {
  title: "Fitcountable — Log workouts and meals by saying what happened.",
  description: "AI-native workout and nutrition tracking with accountability. Log workouts and meals by saying what happened.",
  openGraph: {
    title: "Fitcountable — Log workouts and meals by saying what happened.",
    description: "AI-native workout and nutrition tracking with accountability.",
    type: "website"
  }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={jetBrainsMono.variable}>{children}</body>
    </html>
  );
}
