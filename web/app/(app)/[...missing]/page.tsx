import { DemoStart } from "@/components/demo/demo-start";
import { demoBySlug, demos } from "@/lib/demo/demos";
import { isDemo, isServerless } from "@/lib/local-backend/mode";
import MissingPage from "./missing-page";

// A static build needs one; GitHub Pages serves 404.html for the rest. The
// demo build also has a page per feature demo, e.g. /freeze.
export function generateStaticParams() {
  if (!isServerless) return [];
  return [
    { missing: ["missing"] },
    ...(isDemo ? demos.map((demo) => ({ missing: [demo.slug] })) : []),
  ];
}

export default async function Page({
  params,
}: {
  params: Promise<{ missing: string[] }>;
}) {
  const { missing } = await params;
  const demo =
    isDemo && missing.length === 1 ? demoBySlug(missing[0]) : undefined;
  return demo ? <DemoStart slug={demo.slug} /> : <MissingPage />;
}
