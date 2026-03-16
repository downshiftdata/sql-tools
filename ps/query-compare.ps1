param(
    [Parameter(Mandatory=$true)]
    [string]$Server,

    [Parameter(Mandatory=$true)]
    [string]$Database,

    [string]$Username,

    [SecureString]$Password,

    [Parameter(Mandatory=$true)]
    [string]$Query1,

    [Parameter(Mandatory=$true)]
    [string]$Query2
)

# Build connection string
$connString = "Server=$Server;Database=$Database;"
if ($Username) {
    $connString += "User Id=$Username;Password=$Password;"
} else {
    $connString += "Integrated Security=True;"
}

# Function to execute query and get schema and data
function Get-QueryResult {
    param([string]$query)

    $conn = New-Object System.Data.SqlClient.SqlConnection $connString
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        $reader = $cmd.ExecuteReader()

        # Get schema table
        $schemaTable = $reader.GetSchemaTable()

        # Read data
        $data = @()
        while ($reader.Read()) {
            $row = @{}
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $row[$reader.GetName($i)] = $reader.GetValue($i)
            }
            $data += $row
        }

        return @{Schema = $schemaTable; Data = $data}
    }
    finally {
        if ($reader) { $reader.Close() }
        if ($conn) { $conn.Close() }
    }
}

# Execute queries
try {
    $result1 = Get-QueryResult $Query1
    $result2 = Get-QueryResult $Query2
} catch {
    Write-Error "Error executing queries: $_"
    exit 1
}

# List to collect discrepancies
$discrepancies = @()

# Compare schemas
$schema1 = $result1.Schema
$schema2 = $result2.Schema

if ($schema1.Rows.Count -ne $schema2.Rows.Count) {
    $discrepancies += "Different number of columns: Query1 has $($schema1.Rows.Count), Query2 has $($schema2.Rows.Count)"
} else {
    for ($i = 0; $i -lt $schema1.Rows.Count; $i++) {
        $col1 = $schema1.Rows[$i]
        $col2 = $schema2.Rows[$i]

        if ($col1["ColumnName"] -ne $col2["ColumnName"]) {
            $discrepancies += "Column $i name mismatch: '$($col1["ColumnName"])' vs '$($col2["ColumnName"])'"
        }

        if ($col1["DataTypeName"] -ne $col2["DataTypeName"]) {
            $discrepancies += "Column '$($col1["ColumnName"])' data type mismatch: '$($col1["DataTypeName"])' vs '$($col2["DataTypeName"])'"
        }

        if ($col1["ColumnSize"] -ne $col2["ColumnSize"]) {
            $discrepancies += "Column '$($col1["ColumnName"])' length mismatch: $($col1["ColumnSize"]) vs $($col2["ColumnSize"])"
        }

        if ($col1["NumericPrecision"] -ne $col2["NumericPrecision"]) {
            $discrepancies += "Column '$($col1["ColumnName"])' precision mismatch: $($col1["NumericPrecision"]) vs $($col2["NumericPrecision"])"
        }

        if ($col1["NumericScale"] -ne $col2["NumericScale"]) {
            $discrepancies += "Column '$($col1["ColumnName"])' scale mismatch: $($col1["NumericScale"]) vs $($col2["NumericScale"])"
        }
    }
}

# Compare data
$data1 = $result1.Data
$data2 = $result2.Data

if ($data1.Count -ne $data2.Count) {
    $discrepancies += "Different number of rows: Query1 has $($data1.Count), Query2 has $($data2.Count)"
} else {
    for ($i = 0; $i -lt $data1.Count; $i++) {
        $row1 = $data1[$i]
        $row2 = $data2[$i]

        $keys1 = $row1.Keys | Sort-Object
        $keys2 = $row2.Keys | Sort-Object

        if (Compare-Object $keys1 $keys2) {
            $discrepancies += "Row $i has different columns"
        } else {
            foreach ($key in $keys1) {
                $val1 = $row1[$key]
                $val2 = $row2[$key]

                # Handle nulls and comparison
                if (( $null -eq $val1 -and $null -ne $val2 ) -or ( $null -ne $val1 -and $null -eq $val2 ) -or ( $null -ne $val1 -and $null -ne $val2 -and $val1 -ne $val2 )) {
                    $discrepancies += "Row $i, Column '$key' value mismatch: '$val1' vs '$val2'"
                }
            }
        }
    }
}

# Output results
if ($discrepancies.Count -eq 0) {
    Write-Host "Results match perfectly."
} else {
    Write-Host "Discrepancies found:"
    foreach ($disc in $discrepancies) {
        Write-Host " - $disc"
    }
}