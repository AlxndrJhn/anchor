import { licenseUrl, sourceCodeUrl } from "@/lib/source-code";
import { cn } from "@/lib/utils";

const VERSION = process.env.NEXT_PUBLIC_APP_VERSION;
const LINK =
  "font-semibold text-accent-ink underline decoration-current/35 underline-offset-3 hover:decoration-current";

/** The AGPL's notices, and where to get the source of this version. */
export function LegalNotice({ className }: { className?: string }) {
  return (
    <p className={cn("m-0 text-meta text-muted-foreground", className)}>
      © The Anchor and Anchor+ contributors. Free software under the GNU AGPL
      v3, with no warranty.{" "}
      <a
        href={sourceCodeUrl(VERSION)}
        target="_blank"
        rel="noreferrer"
        className={LINK}
      >
        Source code
      </a>
      {" · "}
      <a
        href={licenseUrl(VERSION)}
        target="_blank"
        rel="noreferrer"
        className={LINK}
      >
        License
      </a>
    </p>
  );
}
