
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
	Param($Server)

	if (CheckServer($Server)) {
		$profile = (Join-Path (Get-Location) "user/profile.json")

		if ([IO.File]::Exists($profile)) {
			if (Login -Server $Server -Profile $profile) {　 # ログイン成功時
				$timestamp = GetTimestamp

				$userdir = (Join-Path (Get-Location) "user/")
				$files = Get-ChildItem -Path $userdir -Name -Filter "transaction-*.json"
				foreach ($file in $files) {
					if ($file -match "[0-9]+") {
						if ($Matches.Values -gt $timestamp) {
							$filepath = (Join-Path $userdir $file)
							# ファイル送信
							$rc = SendFile -Server $server -File $filepath
						}
					}
				}
				UpdateTimestamp　#タイムスタンプ更新
			}
		}
		$script:marker = "+"　#処理成功時のマーカーを更新
	}
}

#アップロード実行
Upload -Server $server

# HTTP
try
{
    $port = 8080
    $url = "http://localhost:$($port)/"

    $listener = new-object Net.HttpListener
    $listener.Prefixes.Add($url)
    $listener.Start()
    Write-Output "$($marker)Server is running at port $($port)"
    Start-Process $url

    # コンテンツタイプを決定
    function ContentType($ext)
    {
		switch ($ext)
		{
			".html" { "text/html" }
			".js" { "text/javascript" }
			".css" { "text/css" }
			".json" { "application/json" }
			".xml" { "text/xml" }
			".gif" { "image/gif" }
			".ico" { "image/x-icon" }
			".jpg" { "image/jpeg" }
			".png" { "image/png" }
			".svg" { "image/svg+xml" }
			".webp" { "image/webp" }
			".zip" { "application/zip" }
			Default { "text/plain" }
		}
    }

    # 404エラーを返す
    function NotFound($response)
    {
        $response.StatusCode = 404
        $response.ContentType = "text/html"
        $content = [Text.Encoding]::UTF8.GetBytes("404 Not Found")
        $stream = $response.OutputStream
        $stream.Write($content, 0, $content.Length)
        $stream.Close()
    }

    #リクエストを処理（無限ループ）
    while ($true)
    {
        if ($request.HttpMethod -eq "GET") {
			if ($path.EndsWith("/")) {
				$path += "index.html"
			}
			$basedir = join-path (get-location) "/"
			$filepath = join-path (get-location) $path
			if ($filepath.StartsWith($basedir)) {
				if ([IO.File]::Exists($filepath)) {
					$response.StatusCode = 200 # OK
					$extension = [IO.Path]::GetExtension($filepath)
					$response.ContentType = ContentType($extension)

					$reader = [IO.File]::OpenRead($filepath)
					$stream = $response.OutputStream
					$reader.CopyTo($stream)
					$stream.Close()
					$reader.Dispose()
				} else {
					NotFound($response) # 404
				}
			} else {
				$response.StatusCode = 403 # Access Violation
			}
			echo "GET $($path) --> $($filepath) [$($response.StatusCode)]"

		# PUT処理
		} elseif ($request.HttpMethod -eq "PUT") {
			$userdir = join-path (get-location) "user/"
			$filepath = join-path (get-location) $path
			if ($filepath.StartsWith($userdir) -and $filepath.EndsWith(".json")) {
				$response.StatusCode = 204 # No Content
				$reader = New-Object System.IO.StreamReader($request.InputStream)
				$text = $reader.ReadToEnd()
				$reader.Close();
				$content = [Text.Encoding]::UTF8.GetBytes($text)

				if ([IO.File]::Exists($filepath)) {
					[IO.File]::Delete($filepath)
				}

				$writer = [IO.File]::OpenWrite($filepath)
				$writer.write($content, 0, $content.Length)
				$writer.Dispose()
			} else {
				$response.StatusCode = 403 # Access Violation
			}
			echo "PUT $($path) --> $($filepath) [$($response.StatusCode)]"

		# DELETE処理
		} elseif ($request.HttpMethod -eq "DELETE") {
			$userdir = join-path (get-location) "user/"
			$filepath = join-path (get-location) $path
			if ($filepath.StartsWith($userdir) -and $filepath.EndsWith(".json")) {
				if ([IO.File]::Exists($filepath)) {
					$response.StatusCode = 204 # No Content
					$timestamp = (Get-Date -Format "yyyyMMddHHmmss")
					$filename = [IO.Path]::GetFileNameWithoutExtension($filepath)
					$histfile = join-path (get-location) "user/$($filename)-$($timestamp).json"
					[IO.File]::Move($filepath, $histfile)
					Upload -Server $server
				} else {
					NotFound($response) # 404
				}
			} else {
				$response.StatusCode = 403 # Access Violation
			}
			echo "DELETE $($path) --> $($filepath) [$($response.StatusCode)]"
		} else {
			$response.StatusCode = 405 # 許可されていないメソッド
		}
		$response.Close()
	}
}
catch
{
    Write-Error $_.Exception
}