extends Node

const FileUtils = preload("res://zfoo/FileUtils.gd")
const RandomUtils = preload("res://zfoo/RandomUtils.gd")
const StringUtils = preload("res://zfoo/StringUtils.gd")
const ByteBufferStorage =preload("res://storage/ByteBuffer.gd")
const ProtocolManagerStorage = preload("res://storage/ProtocolManager.gd")
const ResourceStorage = preload("res://storage/ResourceStorage.gd")
const TcpClient = preload("res://script/TcpClient.gd")
const GetPlayerInfoResponse = preload("res://protocol/protocol/login/GetPlayerInfoResponse.gd")
const BattleResultResponse = preload("res://protocol/protocol/battle/BattleResultResponse.gd")
const CurrencyUpdateNotice = preload("res://protocol/protocol/CurrencyUpdateNotice.gd")
const PlayerExpNotice = preload("res://protocol/protocol/PlayerExpNotice.gd")

@onready var dieAudio: AudioStreamPlayer = $DieAudio
@onready var swooshAudio: AudioStreamPlayer = $SwooshAudio
@onready var transitionAnimation: AnimationPlayer = $Transition/AnimationPlayer
@onready var loading: CanvasLayer = $Loading/CanvasLayer

# 场景常量数据
enum SCENE {Home, Game, Over}
const sceneMap: Dictionary = {
	SCENE.Home: preload("res://scene/Home.tscn"),
	SCENE.Game: preload("res://scene/Game.tscn"),
	SCENE.Over: preload("res://scene/Over.tscn")
}

# 背景图片数据
const backgrounds: Array[Resource] = [preload("res://image/bg_day.png"), preload("res://image/bg_night.png")]
# 当前的背景，随机一个
var currentBackground = backgrounds.front()

# 小鸟动画数据
var birdAnimations: Array[String] = ["blue", "red", "yellow"]
var currentAnimation = birdAnimations.front()

var point: int = 0

# excel配置表数据
var resourceStorage: ResourceStorage

func _init():
	print("开始加载配置表")
	# 加载配置表的数据
	var buffer = ByteBufferStorage.new()

	var poolByteArray = FileUtils.readFileToByteArray("res://godot_resource_storage.bin.tres")
	buffer.writePackedByteArray(poolByteArray)
	var packet = ProtocolManagerStorage.read(buffer)
	resourceStorage = packet
	print(JSON.stringify(packet.objectResources))
	for key in packet.objectResources:
		print(packet.objectResources[key].id)
	
	print("配置表加载完成")
	pass

func _ready():
	swooshAudio.play()
	transitionAnimation.play("fade-in")
	await transitionAnimation.animation_finished
	pass

func changeScene(scene: SCENE):
	var scenePath = sceneMap[scene]
	if (scene == SCENE.Over):
		dieAudio.play()
	else:
		swooshAudio.play()
	transitionAnimation.play_backwards("fade-in")
	await transitionAnimation.animation_finished
	get_tree().change_scene_to_packed(scenePath)
	transitionAnimation.play("fade-in")
	await transitionAnimation.animation_finished
	pass

func randomBackground():
	currentBackground = RandomUtils.randomEle(backgrounds)
	currentAnimation = RandomUtils.randomEle(birdAnimations)
	pass

func showLoading():
	loading.visible = true
	$Loading/CanvasLayer/ColorRect.mouse_filter = Control.MOUSE_FILTER_STOP

func unshowLoading():
	loading.visible = false
	$Loading/CanvasLayer/ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func notify(message: String):
	var notify = preload("res://scene/Notify.tscn").instantiate()
	notify.message = message
	add_child(notify)
	print(message)

# 网络连接服务器相关
#var tcpClient: TcpClient = TcpClient.new("127.0.0.1:16000")
var tcpClient: TcpClient = TcpClient.new("127.0.0.1:16000") if OS.has_feature("editor") else TcpClient.new("47.103.82.45:16000")
# 登录令牌
var token: String = StringUtils.EMPTY
var playInfo: GetPlayerInfoResponse = null

func _process(delta):
	var packet = tcpClient.peekReceivePacket()
	if packet == null:
		return
	if packet is BattleResultResponse:
		tcpClient.popReceivePacket()
		print(StringUtils.format("收到战斗结果:[{}]", [packet.score]))
	elif packet is CurrencyUpdateNotice:
		tcpClient.popReceivePacket()
		playInfo.currencyVo = packet.currencyVo
		print(StringUtils.format("[{}] 货币更新", [packet.currencyVo.gold]))
	elif packet is PlayerExpNotice:
		tcpClient.popReceivePacket()
		notify(StringUtils.format("[level:{}][exp:{}] 经验刷新", [packet.level, packet.exp]))
	pass
