import type { Metadata, Viewport } from "next";
import {
  DM_Sans,
  JetBrains_Mono,
  Patrick_Hand,
  Playfair_Display,
  Space_Grotesk,
} from "next/font/google";
import { appearanceScript } from "@/lib/appearance-script";
import { memoryStorageScript } from "@/lib/demo/memory-storage-script";
import { isDemo } from "@/lib/local-backend/mode";
import { Providers } from "./providers";
import "./globals.css";

const dmSans = DM_Sans({
  variable: "--font-dm-sans",
  subsets: ["latin"],
  display: "swap",
});

const playfair = Playfair_Display({
  variable: "--font-playfair",
  subsets: ["latin"],
  display: "swap",
});

const jetBrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains-mono",
  subsets: ["latin"],
  display: "swap",
});

// The Neo-Brutalism and Lo-fi styles' typefaces, fetched only when used.
const spaceGrotesk = Space_Grotesk({
  variable: "--font-space-grotesk",
  subsets: ["latin"],
  display: "swap",
  preload: false,
});

const patrickHand = Patrick_Hand({
  variable: "--font-patrick-hand",
  weight: "400",
  subsets: ["latin"],
  display: "swap",
  preload: false,
});

export const metadata: Metadata = {
  title: "Anchor",
  description: "Your thoughts, secured",
  other: {
    "apple-mobile-web-app-title": "Anchor",
  },
};

export const viewport: Viewport = {
  interactiveWidget: "resizes-content",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${dmSans.variable} ${playfair.variable} ${jetBrainsMono.variable} ${spaceGrotesk.variable} ${patrickHand.variable}`}
    >
      <head>
        {isDemo && (
          <script
            // biome-ignore lint/security/noDangerouslySetInnerHtml: a fixed script, run before any other
            dangerouslySetInnerHTML={{ __html: memoryStorageScript }}
          />
        )}
        <script
          // biome-ignore lint/security/noDangerouslySetInnerHtml: a fixed script, set before paint
          dangerouslySetInnerHTML={{ __html: appearanceScript }}
        />
      </head>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
