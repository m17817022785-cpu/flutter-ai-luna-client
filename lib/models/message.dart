enum MessageType { text, image }

class Message {
  final String id;
  final String role; // 'user' 或 'assistant'
  String content;    // 文本内容或图片 URL
  final MessageType type;
  bool isGenerating; // 是否处于 Stream 接收态
  
  // 多模态图像参数
  final String? localFilePath;
  final String? base64Image;

  Message({
    required this.id,
    required this.role,
    required this.content,
    this.type = MessageType.text,
    this.isGenerating = false,
    this.localFilePath,
    this.base64Image,
  });

  /// 转换为符合 OpenAI 规范的 API 格式 (适配 Vision 多模态模型)
  Map<String, dynamic> toOpenAiMap() {
    // 如果附带了图片，且是用户发送的信息，需转换为 content-list 格式
    if (role == 'user' && base64Image != null) {
      return {
        'role': role,
        'content': [
          {
            'type': 'text',
            'text': content.isNotEmpty ? content : '分析这张图片。',
          },
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$base64Image',
            }
          }
        ]
      };
    }

    // 普通文本格式
    return {
      'role': role,
      'content': content,
    };
  }
}