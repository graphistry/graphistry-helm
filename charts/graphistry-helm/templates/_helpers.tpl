{{/*
Deployment tier helpers.

Tier ordering: platform (1) < analytics (2) < viz (3) < full (4)
Each tier includes all capabilities of the previous tiers.
*/}}

{{- define "graphistry.tierLevel" -}}
  {{- $tier := .Values.global.tier | default "full" -}}
  {{- if not (has $tier (list "platform" "analytics" "viz" "full")) -}}
    {{- fail (printf "Invalid global.tier: %s. Must be one of: platform, analytics, viz, full" $tier) -}}
  {{- end -}}
  {{- if eq $tier "platform" -}}1
  {{- else if eq $tier "analytics" -}}2
  {{- else if eq $tier "viz" -}}3
  {{- else -}}4
  {{- end -}}
{{- end -}}

{{/* Returns "true" if the tier >= platform (always true) */}}
{{- define "graphistry.tier.platform" -}}true{{- end -}}

{{/* Returns "true" if the tier >= analytics */}}
{{- define "graphistry.tier.analytics" -}}
  {{- if ge (include "graphistry.tierLevel" . | int) 2 -}}true{{- end -}}
{{- end -}}

{{/* Returns "true" if the tier >= viz */}}
{{- define "graphistry.tier.viz" -}}
  {{- if ge (include "graphistry.tierLevel" . | int) 3 -}}true{{- end -}}
{{- end -}}

{{/* Returns "true" if the tier >= full */}}
{{- define "graphistry.tier.full" -}}
  {{- if ge (include "graphistry.tierLevel" . | int) 4 -}}true{{- end -}}
{{- end -}}
