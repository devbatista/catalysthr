# Prawn's standard fonts write Windows-1252, which covers Portuguese; the PDFs replace any
# other character (Documents::AcknowledgmentReceipt), so the warning about it is noise.
Prawn::Fonts::AFM.hide_m17n_warning = true
