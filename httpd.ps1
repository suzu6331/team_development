
$server = "sc.labo.internal"  #サーバーアドレス
$script:session = $null   #セッション変数
$script:marker = "-"  #処理状態

# サーバーのチェックをする関数
function CheckServer($server)
{
	# DNS名の解決・エラーがあれば無視する
	Resolve-DnsName -Name $server -QuickTimeout -ErrorAction SilentlyContinue | Out-Null
	if ($?) {
		if (Test-Connection $server -Quiet -Count 1) {
			Invoke-WebRequest -Uri "http://$($server)/" -Method Head | Out-Null
			if ($?) {
				return $true
			}
		}
	}
	return $false
}

function Login
{
	Param($Server, $Profile)

	$response = Invoke-RestMethod -Uri "http://$($Server)/login.php" -Method Post -ContentType "applic.ation/json" -InFile $Profile -SessionVariable script:session
	return ($response.status -eq 200)
}
