{{/*
Expand the name of the chart.
*/}}
{{- define "sample-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "sample-app.fullname" -}}
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
{{- define "sample-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sample-app.labels" -}}
helm.sh/chart: {{ include "sample-app.chart" . }}
{{ include "sample-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "sample-app.name" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sample-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sample-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sample-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "sample-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the postgres secret
*/}}
{{- define "sample-app.postgresSecretName" -}}
{{- printf "%s-postgres-secret" (include "sample-app.fullname" .) }}
{{- end }}

{{/*
Create the name of the postgres PVC
*/}}
{{- define "sample-app.postgresPVCName" -}}
{{- printf "%s-postgres-data" (include "sample-app.fullname" .) }}
{{- end }}

{{/*
Create the name of the postgres init configmap
*/}}
{{- define "sample-app.postgresInitConfigMapName" -}}
{{- printf "%s-postgres-init" (include "sample-app.fullname" .) }}
{{- end }}

{{/*
Create the name of the app configmap
*/}}
{{- define "sample-app.configMapName" -}}
{{- printf "%s-config" (include "sample-app.fullname" .) }}
{{- end }}

{{/*
Create ingress hostname
*/}}
{{- define "sample-app.ingressHost" -}}
{{- if .Values.ingress.hosts }}
{{- (index .Values.ingress.hosts 0).host }}
{{- else }}
{{- "localhost" }}
{{- end }}
{{- end }}

{{/*
Create storage class name
*/}}
{{- define "sample-app.storageClassName" -}}
{{- if .Values.global.storageClass }}
{{- .Values.global.storageClass }}
{{- else if .Values.database.persistence.storageClass }}
{{- .Values.database.persistence.storageClass }}
{{- else }}
{{- "default" }}
{{- end }}
{{- end }}

{{/*
Create image pull policy
*/}}
{{- define "sample-app.imagePullPolicy" -}}
{{- if .Values.global.imagePullPolicy }}
{{- .Values.global.imagePullPolicy }}
{{- else }}
{{- "IfNotPresent" }}
{{- end }}
{{- end }}

{{/*
Create registry prefix
*/}}
{{- define "sample-app.imageRegistry" -}}
{{- if .Values.global.imageRegistry }}
{{- printf "%s/" .Values.global.imageRegistry }}
{{- end }}
{{- end }}

{{/*
Network policy labels
*/}}
{{- define "sample-app.networkPolicyLabels" -}}
{{- include "sample-app.selectorLabels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end }}