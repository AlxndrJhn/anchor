import { isServerless } from "@/lib/local-backend/mode";
import NoteEditorPage from "./note-page";

// A static build has one page for every note: it reads the note's id from
// the address (see lib/local-backend).
export function generateStaticParams() {
  return isServerless ? [{ id: "new" }] : [];
}

export default function Page() {
  return <NoteEditorPage />;
}
