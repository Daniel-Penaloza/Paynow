module ApplicationHelper
  def receipt_status_badge(status)
    config = case status
             when "verified"   then { label: "Verificado",   classes: "bg-emerald-500/10 text-emerald-400 ring-emerald-500/20" }
             when "rejected"   then { label: "Rechazado",    classes: "bg-red-500/10 text-red-400 ring-red-500/20" }
             when "unreadable" then { label: "No legible",   classes: "bg-slate-500/10 text-slate-400 ring-slate-500/20" }
             else                   { label: "Analizando…",  classes: "bg-amber-500/10 text-amber-400 ring-amber-500/20" }
             end

    content_tag :span, config[:label],
      class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ring-inset shrink-0 #{config[:classes]}"
  end
end
