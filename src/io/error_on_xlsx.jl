
"""
    error_on_xlsx(file)

Rises an error if the file is in XLSX format.
"""
function error_on_xlsx(file)
    # Check if the file extension is XLSX
    if splitext(basename(file))[2] == ".xlsx"
        error("The file is in XLSX format. Please convert it to CSV before using this function.")
    end
    return nothing
end