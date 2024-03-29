{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "hlf-ca.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "hlf-ca.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "hlf-ca.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- /*
Credit: @technosophos
https://github.com/technosophos/common-chart/
labels.standard prints the standard Helm labels.
The standard labels are frequently used in metadata.
*/ -}}
{{- define "labels.standard" -}}
app: {{ include "hlf-ca.name" . }}
heritage: {{ .Release.Service | quote }}
release: {{ .Release.Name | quote }}
chart: {{ include "hlf-ca.chart" . }}
namespace: {{ .Release.Namespace }}
version: {{ .Chart.AppVersion }}
{{- end -}}

{{/*
Generate postgres chart name
*/}}
{{- define "postgresql.fullname" -}}
{{- printf "%s-%s" .Release.Name "postgresql" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create ca server home
*/}}
{{- define "hlf-ca.caServerHome" -}}
{{- if eq "tls" .Values.config.type }}
{{- printf "/var/hyperledger/crypto-config/%s/tls/server" $.Values.global.mspId }}
{{- else }}
{{- printf "/var/hyperledger/crypto-config/%s/ca/server" $.Values.global.mspId }}
{{- end -}}
{{- end -}}

{{/*
Create ca client home
*/}}
{{- define "hlf-ca.caClientHome" -}}
{{- if eq "tls" .Values.config.type }}
{{- printf "/var/hyperledger/crypto-config/%s/tls/admin" $.Values.global.mspId }}
{{- else }}
{{- printf "/var/hyperledger/crypto-config/%s/ca/admin" $.Values.global.mspId }}
{{- end -}}
{{- end -}}

{{/*
Create caClientTlsCertfiles
*/}}
{{- define "hlf-ca.caClientTlsCertfiles" -}}
{{- if eq "tls" .Values.config.type }}
{{- printf "/var/hyperledger/crypto-config/%s/tls/server/ca-cert.pem" $.Values.global.mspId }}
{{- else }}
{{- printf "/var/hyperledger/crypto-config/%s/ca/server/ca-cert.pem" $.Values.global.mspId }}
{{- end -}}
{{- end -}}
