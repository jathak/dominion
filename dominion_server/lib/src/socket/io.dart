import 'package:web_socket_channel/web_socket_channel.dart';
export 'package:web_socket_channel/web_socket_channel.dart';

import 'package:web_socket_channel/io.dart';

WebSocketChannel socketConnect(String url) => IOWebSocketChannel.connect(url);
