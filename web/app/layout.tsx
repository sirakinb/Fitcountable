import type { Metadata } from "next";
import { JetBrains_Mono } from "next/font/google";
import "./styles.css";

const jetBrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains",
  weight: ["400", "500", "600"]
});

export const metadata: Metadata = {
  metadataBase: new URL("https://fitcountable.vercel.app"),
  title: {
    default: "Fitcountable — Log workouts and meals by saying what happened.",
    template: "%s — Fitcountable"
  },
  description:
    "Voice-first workout and nutrition tracking with AI estimates, editable logs, and accountability proof you control.",
  alternates: {
    canonical: "/"
  },
  openGraph: {
    title: "Fitcountable — Log workouts and meals by saying what happened.",
    description:
      "Voice-first workout and nutrition tracking with AI estimates, editable logs, and accountability proof you control.",
    url: "/",
    siteName: "Fitcountable",
    type: "website",
    images: [
      {
        url: "/fitcountable-social-card.png",
        width: 1200,
        height: 630,
        alt: "Fitcountable app preview showing voice-first workout and meal logging"
      }
    ]
  },
  twitter: {
    card: "summary_large_image",
    title: "Fitcountable — Log workouts and meals by saying what happened.",
    description:
      "Voice-first workout and nutrition tracking with AI estimates, editable logs, and accountability proof you control.",
    images: ["/fitcountable-social-card.png"]
  }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={jetBrainsMono.variable}>{children}</body>
    </html>
  );
}
