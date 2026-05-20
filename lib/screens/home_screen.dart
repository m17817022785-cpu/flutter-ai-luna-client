import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/image_save_service.dart';
import '../models/message.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _isImageMode = false;
  File? _attachedFile;
  String? _attachedBase64;

  // API 配置
  String _apiKey = '';
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final settings = await _settingsService.getSettings();
    setState(() {      _apiKey = settings['apiKey']!;
      _baseUrl = settings['baseUrl']!;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } 
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _attachedFile == null) return;
    if (_apiKey.isEmpty) {
      _showSnackBar('请先在设置中配置 API Key');
      return;
    }

    // 用户消息对象
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      localFilePath: _attachedFile?.path,
      base64Image: _attachedBase64,
    );

    setState(() {
      _messages.add(userMessage);
      _inputController.clear();
      _attachedFile = null;
      _attachedBase64 = null;
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      if (_isImageMode) {
        // 生图模式：返回一张图片链接
        final imageUrl = await _apiService.generateImage(text, _apiKey, _baseUrl);
        setState(() {
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: 'assistant',
            content: imageUrl,
            type: MessageType.image,
          ));
        });
      } else {
        // 聊天模式：采用打字机流式输出
        final assistantMessage = Message(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          role: 'assistant',
          content: '',
          isGenerating: true,
        );

        setState(() {
          _messages.add(assistantMessage);
        });

        final responseStream = _apiService.generateChatStream(
          _messages.sublist(0, _messages.length - 1), // 传入历史（包含刚加入的用户消息）
          _apiKey,
          _baseUrl,
          _attachedBase64 != null ? 'gpt-4o' : 'gpt-3.5-turbo',
        );

        await for (final chunk in responseStream) {
          setState(() {
            assistantMessage.content += chunk;
          });
          _scrollToBottom();
        }

        setState(() {
          assistantMessage.isGenerating = false;
        });
      }
    } catch (e) {
      _showSnackBar('发送失败: $e');
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _saveImage(String url) async {
    try {
      _showSnackBar('正在保存图片...');
      await ImageSaveService.saveNetworkImage(url);
      _showSnackBar('图片已成功保存到相册');
    } catch (e) {
      _showSnackBar('保存失败: $e');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( 
      backgroundColor: const Color(0xFF343541),
      appBar: AppBar(
        title: const Text('Luna AI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF343541),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.tune, color: Colors.white), onPressed: _showSettingsDialog),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modeChip('智能聊天', !_isImageMode, () => setState(() => _isImageMode = false)),
                const SizedBox(width: 12),
                _modeChip('AI 生图', _isImageMode, () => setState(() => _isImageMode = true)),
              ],
            ),
          ),
          Expanded( 
            child: _messages.isEmpty 
                ? _buildEmptyState() 
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                  ),
          ),
          if (_isLoading && !_messages.any((m) => m.isGenerating)) 
            const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFF10A37F)),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, size: 64, color: Color(0xFF10A37F)),
          const SizedBox(height: 16),
          const Text(
            '今天我能帮您做些什么？',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '支持 GPT 级别流畅对话及 DALL-E 灵感生图',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF10A37F),
      backgroundColor: const Color(0xFF444654),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.grey[400]),
    );
  }

  Widget _buildMessageBubble(Message msg) {
    final isUser = msg.role == 'user';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      color: isUser ? const Color(0xFF343541) : const Color(0xFF444654),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isUser ? Colors.blueGrey : const Color(0xFF10A37F),
            child: Icon(isUser ? Icons.person : Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.type == MessageType.text)
                  MarkdownBody(
                    data: msg.content.isEmpty && msg.isGenerating ? '●' : msg.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                      code: const TextStyle(color: Colors.orangeAccent, backgroundColor: Colors.black26),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          msg.content,
                          errorBuilder: (c, e, s) => const Text('图片加载失败，请检查网络连接或 API Key。', style: TextStyle(color: Colors.red)),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(color: Color(0xFF10A37F)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _saveImage(msg.content),
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text('保存到相册', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10A37F)),
                      )
                    ],
                  ),
                if (msg.localFilePath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      avatar: const Icon(Icons.image, size: 16, color: Colors.white),
                      label: Text(msg.localFilePath!.split('/').last, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: Colors.white12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFF343541)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachedFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Color(0xFF10A37F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已选择待分析图片: ${_attachedFile!.path.split('/').last}',
                        style: const TextStyle(color: Colors.white, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    IconButton( 
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() {
                        _attachedFile = null;
                        _attachedBase64 = null;
                      }),
                    )
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate, color: Colors.grey, size: 28),
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (picked != null) {
                      final bytes = await File(picked.path).readAsBytes();
                      setState(() {
                        _attachedFile = File(picked.path);
                        _attachedBase64 = base64Encode(bytes);
                      });
                    }
                  },
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF40414F),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '发送消息或输入画图提示词...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF10A37F),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  onPressed: _isLoading ? null : _handleSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final keyCtrl = TextEditingController(text: _apiKey);
    final urlCtrl = TextEditingController(text: _baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF343541),
        title: const Text('API 配置参数', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'API Key',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
            TextField(
              controller: urlCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _settingsService.saveSettings(keyCtrl.text, urlCtrl.text);
              _loadSettings();
              Navigator.pop(context);
            },
            child: const Text('保存修改', style: TextStyle(color: Color(0xFF10A37F))),
          ),
        ],
      ),
    );
  }
}