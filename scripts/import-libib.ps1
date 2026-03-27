param(
  [Parameter(Mandatory = $true)]
  [string]$CsvPath,

  [string]$OutPath = "app/data/books.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Initials {
  param(
    [string]$Publisher,
    [string]$Title
  )

  $source = if ($Publisher) { $Publisher } else { $Title }
  if (-not $source) { return "BK" }

  $parts = @($source -split '[^\p{L}\p{N}]+' | Where-Object { $_ })
  if ($parts.Count -ge 2) {
    return (($parts[0].Substring(0, 1) + $parts[1].Substring(0, 1)).ToUpperInvariant())
  }

  if ($parts.Count -eq 1) {
    return $parts[0].Substring(0, [Math]::Min(3, $parts[0].Length)).ToUpperInvariant()
  }

  return "BK"
}

function Get-Color {
  param([string]$Publisher)

  switch -Regex ($Publisher) {
    'EYROLLES' { return '#a67cf0' }
    '3dtotal|3D TOTAL' { return '#58c18f' }
    'DAIMON|Spring|Hart' { return '#6ea8ff' }
    'TACO' { return '#ff7ac6' }
    default { return '#6ea8ff' }
  }
}

function Get-Tags {
  param(
    [string]$Title,
    [string]$TagText,
    [string]$Group,
    [string]$Collection
  )

  $pool = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $text = @($Title, $TagText, $Group, $Collection) -join ' '

  if ($Collection -match 'Artbooks') {
    foreach ($tag in @('character', 'environment', 'props')) {
      [void]$pool.Add($tag)
    }
  } else {
    foreach ($tag in @('character', 'study', 'anatomy', 'morphology')) {
      [void]$pool.Add($tag)
    }
  }

  if ($text -match 'fantasy|rpg|mmo|mythologie') { [void]$pool.Add('fantasy') }
  if ($text -match 'dark fantasy|bloodborne|elden ring|castlevania|diablo') { [void]$pool.Add('dark fantasy') }
  if ($text -match 'futuristic|sci-fi|watch.?dogs|metal gear|overwatch') { [void]$pool.Add('sci-fi') }
  if ($text -match 'superhero|batman|spider-man') { [void]$pool.Add('superhero') }
  if ($text -match 'horror|survival') { [void]$pool.Add('horror') }
  if ($text -match 'historical|assassin') { [void]$pool.Add('historical') }
  if ($text -match 'mobile') { [void]$pool.Add('ui') }
  if ($text -match 'cartoon|animation') { [void]$pool.Add('cartoon'); [void]$pool.Add('stylized') }
  if ($text -match 'anime|guilty gear|genshin') { [void]$pool.Add('anime'); [void]$pool.Add('stylized') }
  if ($text -match 'drawing|anatom|morpho|squelette|plis|fold|bodybuild') { [void]$pool.Add('study'); [void]$pool.Add('anatomy'); [void]$pool.Add('morphology') }
  if ($text -match 'artwork|stylized|hearthstone|sea of stars|supercell|blizzard') { [void]$pool.Add('stylized') }
  if ($text -match 'adventure|survival|realistic|tomb raider|last of us|metal gear|god of war') { [void]$pool.Add('realistic') }

  return @($pool | Sort-Object)
}

$csv = Import-Csv -Path $CsvPath
$books = @()
$id = 1

foreach ($row in $csv) {
  if (($row.item_type -ne 'book') -or [string]::IsNullOrWhiteSpace($row.title)) {
    continue
  }

  $publisher = if (-not [string]::IsNullOrWhiteSpace($row.publisher)) {
    $row.publisher.Trim()
  } elseif (-not [string]::IsNullOrWhiteSpace($row.group)) {
    $row.group.Trim()
  } else {
    $row.creators.Trim()
  }

  $isbn13 = [string]$row.ean_isbn13
  $isbn10 = [string]$row.upc_isbn10
  $cover = if ($isbn13) {
    "https://covers.openlibrary.org/b/isbn/$isbn13-L.jpg"
  } elseif ($isbn10) {
    "https://covers.openlibrary.org/b/isbn/$isbn10-L.jpg"
  } else {
    ""
  }

  $book = [ordered]@{
    id = $id
    publisher = $publisher
    title = $row.title.Trim()
    color = Get-Color -Publisher $publisher
    cover = $cover
    initials = Get-Initials -Publisher $publisher -Title $row.title
    isbn13 = $isbn13
    isbn10 = $isbn10
    tags = @(Get-Tags -Title $row.title -TagText $row.tags -Group $row.group -Collection $row.collection)
  }

  $books += [pscustomobject]$book
  $id += 1
}

$targetDir = Split-Path -Parent $OutPath
if ($targetDir) {
  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
}

$books | ConvertTo-Json -Depth 5 | Set-Content -Path $OutPath -Encoding UTF8
Write-Output "Imported $($books.Count) books to $OutPath"



