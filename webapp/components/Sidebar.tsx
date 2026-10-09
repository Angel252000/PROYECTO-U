"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

const NAV = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/pautas", label: "Pautas" },
  { href: "/encuestas", label: "Encuestas", proximo: true },
  { href: "/evidencias", label: "Evidencias", proximo: true },
  { href: "/mejora", label: "Plan de mejora", proximo: true },
];

export default function Sidebar({ email }: { email: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const supabase = createClient();

  async function salir() {
    await supabase.auth.signOut();
    router.push("/login");
  }

  return (
    <aside className="flex w-60 shrink-0 flex-col border-r border-black/10 bg-white px-3 py-5">
      <div className="px-3 pb-5">
        <p className="text-sm font-medium">SINAES</p>
        <p className="text-xs text-neutral-500">Autoevaluación 2025</p>
      </div>

      <nav className="flex-1 space-y-1">
        {NAV.map((item) => {
          const activo = pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.proximo ? "#" : item.href}
              className={`flex items-center justify-between rounded-lg px-3 py-2 text-sm ${
                activo
                  ? "bg-marca-50 font-medium text-marca-800"
                  : "text-neutral-700 hover:bg-neutral-100"
              } ${item.proximo ? "cursor-not-allowed opacity-50" : ""}`}
            >
              {item.label}
              {item.proximo && (
                <span className="rounded bg-neutral-100 px-1.5 py-0.5 text-[10px] text-neutral-500">
                  pronto
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-black/10 pt-3">
        <p className="truncate px-3 text-xs text-neutral-500">{email}</p>
        <button
          onClick={salir}
          className="mt-2 w-full rounded-lg px-3 py-2 text-left text-sm text-neutral-700 hover:bg-neutral-100"
        >
          Cerrar sesión
        </button>
      </div>
    </aside>
  );
}
