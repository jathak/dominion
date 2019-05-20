import 'package:web_socket_channel/web_socket_channel.dart';
export 'package:web_socket_channel/web_socket_channel.dart';

import 'package:web_socket_channel/html.dart';

WebSocketChannel socketConnect(String url) => HtmlWebSocketChannel.connect(url);
