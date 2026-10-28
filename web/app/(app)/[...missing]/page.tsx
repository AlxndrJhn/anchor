import { isServerless } from "@/lib/local-backend/mode";
import MissingPage from "./missing-page";

// A static build needs one; GitHub Pages serves 404.html for the rest.
export function generateStaticParams() {
  return isServerless ? [{ missing: ["missing"] }] : [];
}

export default function Page() {
  return <MissingPage />;
}
