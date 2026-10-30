// Features the demo build can't play, because they need a server or another
// app. /demos lists them under the feature demos, each at
// /demos#feature-<slug>.

export interface Feature {
  slug: string;
  title: string;
  /** One line for the list at /demos. */
  summary: string;
  /** Why there's no demo of it. */
  needs: string;
  /** Where to get it, if somewhere else. */
  link?: { label: string; href: string };
}

export const features: Feature[] = [
  {
    slug: "mcp",
    title: "Claude and other MCP apps",
    summary:
      "Claude, and other apps that speak MCP, can search, read and write your notes through your server.",
    needs: "Needs a server",
  },
  {
    slug: "sync",
    title: "Sync across devices",
    summary:
      "Edit offline on the web or your phone; changes sync when you're back online.",
    needs: "Needs a server",
  },
  {
    slug: "sharing",
    title: "Share notes",
    summary: "Share a note with other people on your server, to read or edit.",
    needs: "Needs a server",
  },
  {
    slug: "picture-text-search",
    title: "Search the text in pictures",
    summary:
      "Search finds the words in screenshots and receipts, read on the server.",
    needs: "Needs a server",
  },
  {
    slug: "picture-search",
    title: "Find notes by their pictures",
    summary:
      "Opt-in: search for what pictures show (“receipt”, “Katzen”), in most languages.",
    needs: "Needs a server",
  },
  {
    slug: "oidc",
    title: "Sign in with OIDC",
    summary: "Sign in through Pocket ID, Authelia, Keycloak and the like.",
    needs: "Needs a server",
  },
  {
    slug: "reminders",
    title: "Reminders",
    summary:
      "Set a time on any note and get a notification on your phone, once or repeating.",
    needs: "Needs the Android app",
  },
  {
    slug: "share-to",
    title: "Share to Anchor+",
    summary: "Send text, links, pictures and files to Anchor+ from other apps.",
    needs: "Needs the Android app",
  },
  {
    slug: "desktop-app",
    title: "Desktop app",
    summary:
      "Your server's web client in its own window on Windows and macOS, updating itself.",
    needs: "Needs the desktop app",
    link: {
      label: "Download the latest release",
      href: "https://github.com/AlxndrJhn/anchor/releases/latest",
    },
  },
];
