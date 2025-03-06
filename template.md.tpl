{{- if . }}
### {{ escapeXML ( index . 0 ).Target }} - Trivy Report

{{- range . }}
{{- if (eq (len .Vulnerabilities) 0) }}
{{- else }}
#### {{ .Type | toString | escapeXML }}

| Package | Vulnerability ID | Severity | Installed Version | Fixed Version | Links |
| ------- | ---------------- | -------- | ----------------- | ------------- | ----- |
{{- range .Vulnerabilities }}
| {{ escapeXML .PkgName }} | {{ escapeXML .VulnerabilityID }} | {{ escapeXML .Vulnerability.Severity }} | {{ escapeXML .InstalledVersion }} | {{ escapeXML .FixedVersion }} | <details>{{ range .Vulnerability.References }}<a href={{ escapeXML . | printf "%q" }}>{{ escapeXML . }}</a>{{ end }}<p><summary>References</summary></p></details> |
{{- end }}

{{- end }}
{{- if (eq (len .Misconfigurations ) 0) }}
{{- else }}
#### {{ .Type | toString | escapeXML }}

| Type | Misconf ID | Check | Severity | Message |
| ---- | ---------- | ----- | -------- | ------- |
{{- range .Vulnerabilities }}
| {{ escapeXML .Type }} | {{ escapeXML .ID }} | {{ escapeXML .Title }} | {{ escapeXML .Severity }} | {{ escapeXML .Message }}<br><a href={{ escapeXML .PrimaryURL | printf "%q" }}>{{ escapeXML .PrimaryURL }}</a> |

{{- end }}
{{- end }}

{{- else }}
### Trivy returned an empty response
{{- end }}
{{- end }}
