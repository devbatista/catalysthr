# Each Active Storage file has its virus scan (P-05-30, D-640), read with the file to
# avoid one query per file on the screens.
ActiveSupport.on_load(:active_storage_blob) do
  has_one :file_scan, dependent: nil
end
