import Link from "next/link";
import { publicPath } from "@/lib/local-backend/mode";
import { cn } from "@/lib/utils";
import { PlusMark } from "./plus-mark";

/** The app's icon: a ruled pad with a brass anchor on slate cloth. */
export function AnchorLogo({ className }: { className?: string }) {
  return (
    <img
      src={publicPath("/anchor-mark.svg")}
      alt=""
      aria-hidden
      draggable={false}
      className={cn("flex-none rounded-sm shadow-edge", className)}
    />
  );
}

const wordmarkClass =
  "whitespace-nowrap font-bold font-serif text-[19px] tracking-[-.005em]";

export function Brand({
  href,
  className,
  nameClassName,
  isBurstOnShow = false,
  onNavigate,
}: {
  href?: string;
  className?: string;
  nameClassName?: string;
  /** Plays the +'s features once when it first shows, where it shows
   * seldom, like signing in. */
  isBurstOnShow?: boolean;
  onNavigate?: () => void;
}) {
  const content = (
    <>
      <AnchorLogo className="size-7" />
      <span
        data-slot="brand-name"
        className={cn(wordmarkClass, "inline-flex items-start", nameClassName)}
      >
        Anchor<span className="sr-only">+</span>
        <PlusMark
          size={11}
          isBurstOnShow={isBurstOnShow}
          className="mt-[0.36em] ml-[3px]"
        />
      </span>
    </>
  );
  const classes = cn(
    "flex min-w-0 flex-1 items-center gap-2 rounded-sm text-inherit no-underline",
    className,
  );
  return href ? (
    <Link href={href} className={classes} onClick={onNavigate}>
      {content}
    </Link>
  ) : (
    <span className={classes}>{content}</span>
  );
}
