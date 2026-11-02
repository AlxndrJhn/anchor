import { isServerless } from "@/lib/local-backend/mode";
import SharedNotePage from "./shared-note-page";

// Share links need a server; a static build has a page here only so the
// build has one to export.
export function generateStaticParams() {
  return isServerless ? [{ token: "none" }] : [];
}

export default function Page() {
  return <SharedNotePage />;
}
