-- サウンドシステム管理
local SoundService = game:GetService("SoundService")

-- サウンドライブラリの整理
local soundLibrary = {
	ui = {
		buttonClick = "rbxassetid://12222005",
		success = "rbxassetid://138081500"
	},
	gameplay = {
		checkpoint = "rbxassetid://138081500",
		collectible = "rbxassetid://911882310"
	}
}

-- サウンド再生関数
local function playSound(soundId, volume, parent)
	-- サウンドオブジェクトを作成
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5 -- デフォルト音量
	
	-- 親を設定（指定がない場合はSoundService）
	sound.Parent = parent or SoundService
	
	-- 再生して終了時に削除
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	
	return sound
end

-- ライブラリからカテゴリと名前で再生
local function playLibrarySound(category, soundName, volume, parent)
	local soundId = soundLibrary[category] and soundLibrary[category][soundName]
	
	if not soundId then
		warn("Sound not found: " .. category .. "." .. soundName)
		return nil
	end
	
	return playSound(soundId, volume, parent)
end

-- エクスポート
return {
	playSound = playSound,
	playLibrarySound = playLibrarySound,
	soundLibrary = soundLibrary
}