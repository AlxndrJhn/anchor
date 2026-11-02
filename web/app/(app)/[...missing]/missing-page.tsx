"use client";

import { NotebookPen, Search } from "lucide-react";
import Link from "next/link";
import { AppPage } from "@/components/layout/app-page";
import { ErrorScreen } from "@/components/layout/error-screen";
import { Button } from "@/components/ui/button";
import { useDocumentTitle } from "@/lib/hooks/use-document-title";

export default function MissingPage() {
  useDocumentTitle("Page not found");
  return (
    <AppPage title={null}>
      <ErrorScreen
        illustration="missing"
        title="Page not found"
        text="Check the address, or go back to your notes."
        actions={
          <>
            <Button asChild>
              <Link href="/notes">
                <NotebookPen aria-hidden />
                Go to your notes
              </Link>
            </Button>
            <Button variant="secondary" asChild>
              <Link href="/notes?search=1">
                <Search aria-hidden />
                Search notes
              </Link>
            </Button>
          </>
        }
      />
    </AppPage>
  );
}
