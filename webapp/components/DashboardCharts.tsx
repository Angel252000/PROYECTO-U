"use client";

import {
  Radar,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  ResponsiveContainer,
} from "recharts";
import type { DimensionScore } from "@/lib/types";
import { colorPorcentaje } from "@/lib/sinaes";

export default function DashboardCharts({
  dimensiones,
}: {
  dimensiones: DimensionScore[];
}) {
  const data = dimensiones.map((d) => ({
    dim: d.dimension_codigo,
    nombre: d.dimension_nombre,
    pct: Number(d.porcentaje ?? 0),
  }));

  return (
    <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2">
      <div className="rounded-xl border border-black/10 bg-white p-4">
        <p className="mb-2 text-sm font-medium">Conformidad por dimensión</p>
        <div className="h-64 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <RadarChart data={data} outerRadius="70%">
              <PolarGrid stroke="rgba(0,0,0,0.1)" />
              <PolarAngleAxis
                dataKey="dim"
                tick={{ fontSize: 11, fill: "#6b6b66" }}
              />
              <PolarRadiusAxis domain={[0, 100]} tick={{ fontSize: 10 }} />
              <Radar
                dataKey="pct"
                stroke="#378ADD"
                fill="#378ADD"
                fillOpacity={0.2}
              />
            </RadarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="rounded-xl border border-black/10 bg-white p-4">
        <p className="mb-3 text-sm font-medium">Avance por dimensión</p>
        <div className="space-y-3">
          {data.length === 0 && (
            <p className="text-sm text-neutral-500">Aún no hay datos.</p>
          )}
          {data.map((d) => (
            <div key={d.dim}>
              <div className="mb-1 flex justify-between text-xs">
                <span className="text-neutral-600">
                  {d.dim} · {d.nombre}
                </span>
                <span
                  className="font-medium"
                  style={{ color: colorPorcentaje(d.pct) }}
                >
                  {Math.round(d.pct)}%
                </span>
              </div>
              <div className="h-2 overflow-hidden rounded-full bg-neutral-100">
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${d.pct}%`,
                    background: colorPorcentaje(d.pct),
                  }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
