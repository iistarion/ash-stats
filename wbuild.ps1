$VERSION_DATE = Get-Date -Format "MMdd"
if ($args[0] -eq "push" -or -not $args[0]) {
    $ARG0 = "01"
} else {
    $ARG0 = [string]$args[0]
}
$ASH_STATS_VERSION = "1.$VERSION_DATE.$ARG0"
$ASH_STATS_VERSION | Set-Content -Path "version.txt"


echo "Building version: '$ASH_STATS_VERSION'"
docker build -t cyaque/ash-stats:$ASH_STATS_VERSION .

if ($args[0] -eq "push" -or $args[1] -eq "push") {
    docker tag cyaque/ash-stats:$ASH_STATS_VERSION cyaque/ash-stats:latest
    docker push cyaque/ash-stats:$ASH_STATS_VERSION
    docker push cyaque/ash-stats:latest
}
