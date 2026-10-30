"use client";

import { DemoList } from "@/components/demo/demo-list";
import { AppPage, PageTitle } from "@/components/layout/app-page";
import { isDemo } from "@/lib/local-backend/mode";
import MissingPage from "../[...missing]/missing-page";

/** The demo build's feature demos, and the features it can't demo. */
export default function DemosPage() {
  if (!isDemo) return <MissingPage />;
  return (
    <AppPage title={<PageTitle>Feature demos</PageTitle>} scrollKey="demos">
      <DemoList />
    </AppPage>
  );
}
