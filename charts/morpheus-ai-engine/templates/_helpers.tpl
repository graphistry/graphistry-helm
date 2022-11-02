# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

{{/*
Expand the name of the chart.
*/}}
{{- define "morpheus-ai-engine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "morpheus-ai-engine.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "morpheus-ai-engine.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "morpheus-ai-engine.labels" -}}
helm.sh/chart: {{ include "morpheus-ai-engine.chart" . }}
{{ include "morpheus-ai-engine.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
#app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "morpheus-ai-engine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "morpheus-ai-engine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "morpheus-ai-engine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "morpheus-ai-engine.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" }}
{{- end }}
{{- end }}

{{/*
Generate a dockerconfig json secret from the provided NGC API key
*/}}
{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"nvcr.io\": {\"auth\": \"%s\"}}}" (printf "%s:%s" .Values.ngc.username .Values.ngc.apiKey | b64enc) | b64enc }}
{{- end }}

