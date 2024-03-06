
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

#ログインする
function Login
{
	Param($Server, $Profile)
	# ログインAPIに対してPOSTを送信
	$response = Invoke-RestMethod -Uri "http://$($Server)/login.php" -Method Post -ContentType "applic.ation/json" -InFile $Profile -SessionVariable script:session
	return ($response.status -eq 200)  #ステータスが200ならログイン成功
}

#サーバーにファイル送信する
function SendFile
{
    Param($Server, $File)
    # ファイル更新APIに対してPOSTを送信
    $response = Invoke-RestMethod -Uri "http://$($Server)/update.php" -Method Post -ContentType "application/json" -InFile $File -WebSession $script:session
    return ($response.status -eq 204)  #ステータス204なら送信成功
}

#タイムスタンプの取得する
function GetTimestamp
{
	$filepath = (Join-Path (Get-Location) "user/timestamp.txt")
	if ([IO.File]::Exists($filepath)) {
		$t = Get-Content $filepath
	} else {
		$t = "00000000000000"  #ファイルが存在しない時はデフォルトの値
	}
	return $t
}

#タイムスタンプ更新
function UpdateTimestamp
{
    $filepath = (Join-Path (Get-Location) "user/timestamp.txt")
    Get-Date -Format "yyyyMMddHHmmss" > $filepath
}

#ファイルをアップロード
function Upload
{
	Param()
}

# HTTP
try{
    
} catch {
    Write-Error $_.Exception
}