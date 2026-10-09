"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  const [modo, setModo] = useState<"login" | "registro">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [nombre, setNombre] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [cargando, setCargando] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    setCargando(true);

    if (modo === "login") {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) setMsg(error.message);
      else router.push("/dashboard");
    } else {
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { nombre } },
      });
      if (error) setMsg(error.message);
      else setMsg("Cuenta creada. Revisa tu correo para confirmar e inicia sesión.");
    }
    setCargando(false);
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-sm rounded-xl border border-black/10 bg-white p-8">
        <div className="mb-6 text-center">
          <h1 className="text-xl font-medium">Plataforma SINAES</h1>
          <p className="mt-1 text-sm text-neutral-500">
            Autoevaluación · Modelo de Grado 2025
          </p>
        </div>

        <form onSubmit={onSubmit} className="space-y-3">
          {modo === "registro" && (
            <input
              type="text"
              placeholder="Nombre completo"
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              className="w-full rounded-lg border border-black/15 px-3 py-2 text-sm outline-none focus:border-marca-500"
            />
          )}
          <input
            type="email"
            placeholder="Correo electrónico"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            className="w-full rounded-lg border border-black/15 px-3 py-2 text-sm outline-none focus:border-marca-500"
          />
          <input
            type="password"
            placeholder="Contraseña"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            className="w-full rounded-lg border border-black/15 px-3 py-2 text-sm outline-none focus:border-marca-500"
          />

          <button
            type="submit"
            disabled={cargando}
            className="w-full rounded-lg bg-marca-600 px-3 py-2 text-sm font-medium text-white hover:bg-marca-800 disabled:opacity-60"
          >
            {cargando
              ? "Procesando…"
              : modo === "login"
                ? "Iniciar sesión"
                : "Crear cuenta"}
          </button>
        </form>

        {msg && <p className="mt-3 text-center text-sm text-neutral-600">{msg}</p>}

        <button
          onClick={() => {
            setMsg(null);
            setModo(modo === "login" ? "registro" : "login");
          }}
          className="mt-4 w-full text-center text-sm text-marca-600 hover:underline"
        >
          {modo === "login"
            ? "¿No tienes cuenta? Crear una"
            : "Ya tengo cuenta · Iniciar sesión"}
        </button>
      </div>
    </div>
  );
}
