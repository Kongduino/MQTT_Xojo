#tag Module
Protected Module AppConfig
	#tag Method, Flags = &h0
		Function AppBrokerDescription() As String
		  // "host:port, TLS 1.2" or "host:port, plain TCP" for the log (never the credentials)
		  Dim d As String = mHost + ":" + Str(mPort)
		  If mTLS Then
		    d = d + ", TLS " + mTLSVersion
		  Else
		    d = d + ", plain TCP"
		  End If
		  Return d
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppClientID() As String
		  Return mClientID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppConfigFile() As FolderItem
		  // MQTT_Xojo.config.json, next to the app or in one of its parent folders (up to 6 levels):
		  // that finds it in the project folder both for debug runs and for builds in "Builds - MQTT_Xojo/<platform>/".
		  // The file holds the credentials and keys and is excluded from the repository (.gitignore)
		  Dim folder As FolderItem = App.ExecutableFile.Parent
		  For level As Integer = 0 To 6
		    If folder = Nil Then Exit For
		    Dim f As FolderItem = folder.Child("MQTT_Xojo.config.json")
		    If f <> Nil And f.Exists Then Return f
		    folder = folder.Parent
		  Next
		  Return Nil
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppConfigPath() As String
		  Return mConfigPath
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppDedupe() As Boolean
		  // options.dedupe: show and republish each packet (sender + id) only once in 10 minutes. Default false,
		  // like mqtt-converter, which republishes every copy
		  Return mDedupe
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppHasNode() As Boolean
		  // True when the configuration has a "node" section: the app then sends into the mesh (downlink)
		  Return mHasNode
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppHexDump() As Boolean
		  // options.hexdump: hex dump of the raw MQTT data in the window. Default false
		  Return mHexDump
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppHost() As String
		  Return mHost
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppJSONQoS() As Integer
		  Return mJSONQoS
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppLoadConfig() As String
		  // Reads MQTT_Xojo.config.json: broker, topics and channel keys (see MQTT_Xojo.config.example.json).
		  // Returns "" when OK, otherwise what is wrong
		  Dim f As FolderItem = AppConfigFile()
		  If f = Nil Then Return "MQTT_Xojo.config.json not found next to the app or in its parent folders. Copy MQTT_Xojo.config.example.json to MQTT_Xojo.config.json in the project folder and fill it in."
		  mConfigPath = f.NativePath
		  Dim text As String
		  Try
		    Dim tis As TextInputStream = TextInputStream.Open(f)
		    text = tis.ReadAll(Encodings.UTF8)
		    tis.Close
		  Catch err As IOException
		    Return "Can't read " + mConfigPath + ": " + err.Message
		  End Try
		  Dim config As JSONItem
		  Try
		    config = New JSONItem(text)
		  Catch err As JSONException
		    Return "Invalid JSON in " + mConfigPath + ": " + err.Message
		  End Try
		  Dim badChannels() As String
		  Try
		    Dim broker As JSONItem = JSONItem(config.Value("broker").ObjectValue)
		    mHost = broker.Value("host").StringValue
		    // broker.tls: MQTT over TLS (port 8883 unless given); broker.tls_version: "1.2" (default), "1.3" or "auto"
		    mTLS = False
		    If broker.HasKey("tls") Then mTLS = broker.Value("tls").BooleanValue
		    mTLSVersion = "1.2"
		    If broker.HasKey("tls_version") Then mTLSVersion = broker.Value("tls_version").StringValue
		    If mTLSVersion <> "1.2" And mTLSVersion <> "1.3" And mTLSVersion <> "auto" Then Return "Invalid broker.tls_version """ + mTLSVersion + """ in " + mConfigPath + " (use ""1.2"", ""1.3"" or ""auto"")"
		    mPort = 1883
		    If mTLS Then mPort = 8883
		    If broker.HasKey("port") Then mPort = broker.Value("port").IntegerValue
		    mUsername = ""
		    If broker.HasKey("username") Then mUsername = broker.Value("username").StringValue
		    mPassword = ""
		    If broker.HasKey("password") Then mPassword = broker.Value("password").StringValue
		    mClientID = ""
		    If broker.HasKey("client_id") Then mClientID = broker.Value("client_id").StringValue
		    mTopics.RemoveAll
		    Dim topics As JSONItem = JSONItem(config.Value("topics").ObjectValue)
		    For i As Integer = 0 To topics.Count - 1
		      mTopics.Add(topics.ValueAt(i).StringValue)
		    Next
		    mDedupe = False
		    mHexDump = False
		    // options.reconnect (default on), reconnect_max_delay (s, default 60), reconnect_give_up (s, default 900 = 15 minutes)
		    mReconnect = True
		    mReconnectMaxDelay = 60
		    mReconnectGiveUp = 900
		    // options.send_qos: QoS of our sends and NodeInfo (default 1, confirmed by the broker);
		    // options.json_qos: QoS of the JSON republished for every received packet (default 0)
		    mSendQoS = 1
		    mJSONQoS = 0
		    If config.HasKey("options") Then
		      Dim options As JSONItem = JSONItem(config.Value("options").ObjectValue)
		      If options.HasKey("dedupe") Then mDedupe = options.Value("dedupe").BooleanValue
		      If options.HasKey("hexdump") Then mHexDump = options.Value("hexdump").BooleanValue
		      If options.HasKey("reconnect") Then mReconnect = options.Value("reconnect").BooleanValue
		      If options.HasKey("reconnect_max_delay") Then mReconnectMaxDelay = options.Value("reconnect_max_delay").IntegerValue
		      If options.HasKey("reconnect_give_up") Then mReconnectGiveUp = options.Value("reconnect_give_up").IntegerValue
		      If options.HasKey("send_qos") Then mSendQoS = options.Value("send_qos").IntegerValue
		      If options.HasKey("json_qos") Then mJSONQoS = options.Value("json_qos").IntegerValue
		      If mSendQoS < 0 Or mSendQoS > 1 Or mJSONQoS < 0 Or mJSONQoS > 1 Then Return "options.send_qos and options.json_qos must be 0 or 1 in " + mConfigPath
		    End If
		    mHasNode = False
		    If config.HasKey("node") Then
		      // The app's own (virtual) node, for sending into the mesh (downlink)
		      Dim node As JSONItem = JSONItem(config.Value("node").ObjectValue)
		      Dim idText As String = node.Value("id").StringValue
		      If Not MeshParseNodeID(idText, mNodeNum) Or mNodeNum = 0 Then Return "Invalid node id """ + idText + """ in " + mConfigPath + " (use !aabbccdd)"
		      mNodeID = MeshHexID(mNodeNum)
		      mNodeLongName = "Xojo MQTT"
		      If node.HasKey("long_name") Then mNodeLongName = node.Value("long_name").StringValue
		      mNodeShortName = "XOJO"
		      If node.HasKey("short_name") Then mNodeShortName = node.Value("short_name").StringValue
		      mNodeRoot = ""
		      If node.HasKey("root") Then mNodeRoot = node.Value("root").StringValue
		      // node.private_key (base64, 32 bytes): the node's Curve25519 key for PKI direct messages. Keep it: nodes pin
		      // the first public key they learn for a node and drop NodeInfo with a different one
		      Dim privateKey As String
		      If node.HasKey("private_key") Then privateKey = DecodeBase64(node.Value("private_key").StringValue)
		      If Not MeshSetPKIIdentity(mNodeNum, privateKey) Then Return "Invalid node.private_key in " + mConfigPath + " (base64 of 32 bytes)"
		      mHasNode = True
		    Else
		      Call MeshSetPKIIdentity(0, "")
		    End If
		    // public_keys: {"!aabbccdd": "base64 public key"}, recipients of PKI direct messages
		    MeshClearConfigKeys
		    If config.HasKey("public_keys") Then
		      Dim keys As JSONItem = JSONItem(config.Value("public_keys").ObjectValue)
		      For Each nodeText As String In keys.Keys
		        Dim keyNum As UInt32
		        Dim keyBytes As String = DecodeBase64(keys.Value(nodeText).StringValue)
		        If Not MeshParseNodeID(nodeText, keyNum) Or keyBytes.Bytes <> 32 Then Return "Invalid public_keys entry """ + nodeText + """ in " + mConfigPath + " (node id and base64 of 32 bytes)"
		        MeshSetPublicKey(keyNum, keyBytes)
		      Next
		    End If
		    MeshClearChannels
		    Dim channels As JSONItem = JSONItem(config.Value("channels").ObjectValue)
		    For j As Integer = 0 To channels.Count - 1
		      Dim channel As JSONItem = JSONItem(channels.ValueAt(j).ObjectValue)
		      Dim channelName As String = channel.Value("name").StringValue
		      If Not MeshAddChannel(channelName, channel.Value("psk").StringValue) Then badChannels.Add(channelName)
		    Next
		  Catch err As RuntimeException
		    Return "Incomplete configuration in " + mConfigPath + _
		    " (" + err.Message + _
		    "). Expected: broker {host, port, username, password, client_id}, topics [...], channels [{name, psk}], optional options {dedupe, hexdump}, node {id, long_name, short_name, root, private_key} and public_keys {""!id"": key}"
		  End Try
		  If mHost = "" Then Return "No broker host in " + mConfigPath
		  If badChannels.Count > 0 Then Return "Invalid PSK for channel(s) " + String.FromArray(badChannels, ", ") + " in " + mConfigPath
		  Return ""
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppNodeID() As String
		  Return mNodeID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppNodeLongName() As String
		  Return mNodeLongName
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppNodeNum() As UInt32
		  Return mNodeNum
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppNodeRoot() As String
		  // node.root, e.g. "msh/EU_868": where the NodeInfo is published at connect ("" = not published)
		  Return mNodeRoot
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppNodeShortName() As String
		  Return mNodeShortName
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppPassword() As String
		  Return mPassword
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppPort() As Integer
		  Return mPort
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppReconnect() As Boolean
		  Return mReconnect
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppReconnectGiveUp() As Integer
		  Return mReconnectGiveUp
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppReconnectMaxDelay() As Integer
		  Return mReconnectMaxDelay
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppSendQoS() As Integer
		  Return mSendQoS
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppTLS() As Boolean
		  // broker.tls: connect with TLS
		  Return mTLS
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppTLSConnectionType() As SSLSocket.SSLConnectionTypes
		  // broker.tls_version as the SSLSocket connection type. "auto" (SSLv23) negotiates the best version both sides support
		  Select Case mTLSVersion
		  Case "1.3"
		    Return SSLSocket.SSLConnectionTypes.TLSv13
		  Case "auto"
		    Return SSLSocket.SSLConnectionTypes.SSLv23
		  Else
		    Return SSLSocket.SSLConnectionTypes.TLSv12
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppTopic(index As Integer) As String
		  Return mTopics(index)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppTopicCount() As Integer
		  Return mTopics.Count
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppUsername() As String
		  Return mUsername
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mClientID As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mConfigPath As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mDedupe As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mHasNode As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mHexDump As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mHost As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mJSONQoS As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mNodeID As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mNodeLongName As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mNodeNum As UInt32
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mNodeRoot As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mNodeShortName As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPassword As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPort As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mReconnect As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mReconnectGiveUp As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mReconnectMaxDelay As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mSendQoS As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mTLS As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mTLSVersion As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mTopics() As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mUsername As String
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Module
#tag EndModule
