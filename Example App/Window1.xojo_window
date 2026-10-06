#tag DesktopWindow
Begin DesktopWindow Window1
   Backdrop        =   0
   BackgroundColor =   &cFFFFFF
   Composite       =   False
   DefaultLocation =   2
   FullScreen      =   False
   HasBackgroundColor=   False
   HasCloseButton  =   True
   HasFullScreenButton=   False
   HasMaximizeButton=   True
   HasMinimizeButton=   True
   HasTitleBar     =   True
   Height          =   568
   ImplicitInstance=   True
   MacProcID       =   0
   MaximumHeight   =   32000
   MaximumWidth    =   32000
   MenuBar         =   1872400383
   MenuBarVisible  =   False
   MinimumHeight   =   64
   MinimumWidth    =   64
   Resizeable      =   True
   Title           =   "MQTT_Xojo"
   Type            =   0
   Visible         =   True
   Width           =   818
   Begin DesktopTextArea MessagesArea
      AllowAutoDeactivate=   True
      AllowFocusRing  =   True
      AllowSpellChecking=   True
      AllowStyledText =   True
      AllowTabs       =   False
      BackgroundColor =   16777215
      Bold            =   False
      Enabled         =   True
      FontName        =   "monaco"
      FontSize        =   13.0
      FontUnit        =   0
      Format          =   ""
      HasBorder       =   True
      HasHorizontalScrollbar=   False
      HasVerticalScrollbar=   True
      Height          =   448
      HideSelection   =   True
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   False
      Left            =   20
      LineHeight      =   0.0
      LineSpacing     =   1.0
      LockBottom      =   True
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   True
      LockTop         =   True
      MaximumCharactersAllowed=   0
      Multiline       =   True
      ReadOnly        =   True
      Scope           =   0
      TabIndex        =   0
      TabPanelIndex   =   0
      TabStop         =   True
      Text            =   ""
      TextAlignment   =   0
      TextColor       =   0
      Tooltip         =   ""
      Top             =   60
      Transparent     =   False
      Underline       =   False
      UnicodeMode     =   0
      ValidationMask  =   ""
      Visible         =   True
      Width           =   778
   End
   Begin MQTTClient MQTTClient1
      Address         =   ""
      BytesAvailable  =   0
      BytesLeftToSend =   0
      CertificatePassword=   ""
      Index           =   -2147483648
      InitialParent   =   ""
      LastErrorCode   =   0
      LockedInPosition=   False
      Port            =   0
      Scope           =   0
      SSLConnected    =   False
      SSLConnecting   =   False
      SSLConnectionType=   5
      SSLEnabled      =   False
      TabPanelIndex   =   0
   End
   Begin DesktopButton btConnect
      AllowAutoDeactivate=   True
      Bold            =   False
      Cancel          =   False
      Caption         =   "Connect"
      Default         =   True
      Enabled         =   True
      FontName        =   "System"
      FontSize        =   0.0
      FontUnit        =   0
      Height          =   28
      Index           =   -2147483648
      Italic          =   False
      Left            =   20
      LockBottom      =   False
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   False
      LockTop         =   True
      MacButtonStyle  =   0
      Scope           =   0
      TabIndex        =   1
      TabPanelIndex   =   0
      TabStop         =   True
      Tooltip         =   ""
      Top             =   20
      Transparent     =   False
      Underline       =   False
      Visible         =   True
      Width           =   85
   End
   Begin DesktopButton btClear
      AllowAutoDeactivate=   True
      Bold            =   False
      Cancel          =   False
      Caption         =   "Clear"
      Default         =   False
      Enabled         =   True
      FontName        =   "System"
      FontSize        =   0.0
      FontUnit        =   0
      Height          =   28
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   False
      Left            =   117
      LockBottom      =   False
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   False
      LockTop         =   True
      MacButtonStyle  =   0
      Scope           =   0
      TabIndex        =   2
      TabPanelIndex   =   0
      TabStop         =   True
      Tooltip         =   ""
      Top             =   20
      Transparent     =   False
      Underline       =   False
      Visible         =   True
      Width           =   89
   End
   Begin DesktopButton btSave
      AllowAutoDeactivate=   True
      Bold            =   False
      Cancel          =   False
      Caption         =   "Save logs"
      Default         =   False
      Enabled         =   True
      FontName        =   "System"
      FontSize        =   0.0
      FontUnit        =   0
      Height          =   28
      Index           =   -2147483648
      Italic          =   False
      Left            =   218
      LockBottom      =   False
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   False
      LockTop         =   True
      MacButtonStyle  =   0
      Scope           =   0
      TabIndex        =   3
      TabPanelIndex   =   0
      TabStop         =   True
      Tooltip         =   ""
      Top             =   20
      Transparent     =   False
      Underline       =   False
      Visible         =   True
      Width           =   89
   End
End
#tag EndDesktopWindow

#tag WindowCode
#tag EndWindowCode

#tag Events MessagesArea
	#tag Event
		Sub Opening()
		  // The send row (To, channel, message, Send) is created in code under this area
		  SendBoxCreate(Self, Me)
		  AppResetLogStart
		End Sub
	#tag EndEvent
#tag EndEvents
#tag Events MQTTClient1
	#tag Event
		Sub Reconnecting(attempt As Integer, delaySeconds As Integer, reason As String)
		  // attempt is the number of the next try: the first line says what happened, the next ones that a retry failed
		  If attempt <= 1 Then
		    If AppHasConnected() Then
		      AppLog("Connection lost (" + reason + "). Reconnecting in " + Str(delaySeconds) + " s (attempt 1)")
		    Else
		      AppLog("Connection failed (" + reason + "). Retrying in " + Str(delaySeconds) + " s (attempt 1)")
		    End If
		  Else
		    AppLog("Attempt " + Str(attempt - 1) + " failed (" + reason + "). Retrying in " + Str(delaySeconds) + " s (attempt " + Str(attempt) + ")")
		  End If
		  AppSetConnectButton(True) // a click stops the reconnection
		End Sub
	#tag EndEvent
	#tag Event
		Sub ReconnectFailed(reason As String)
		  AppLog("Gave up reconnecting (last error: " + reason + "). Click Connect to try again")
		  AppSetConnectButton(False)
		End Sub
	#tag EndEvent
	#tag Event
		Sub MQTTDisconnected()
		  If MQTTClient1.IsReconnecting Then Return // reported by the Reconnecting line
		  AppLog("Disconnected from the broker")
		  AppSetConnectButton(False)
		End Sub
	#tag EndEvent
	#tag Event
		Sub MQTTConnectionRefused(reasonCode As Integer)
		  // CONNACK return codes of MQTT 3.1.1
		  Dim reason As String
		  Select Case reasonCode
		  Case 1
		    reason = "unacceptable protocol version"
		  Case 2
		    reason = "client identifier rejected"
		  Case 3
		    reason = "server unavailable"
		  Case 4
		    reason = "bad username or password"
		  Case 5
		    reason = "not authorized"
		  Else
		    reason = "unknown reason"
		  End Select
		  AppLog("The broker refused the connection: " + reason + " (code " + Str(reasonCode) + ")")
		  If Not MQTTClient1.IsReconnecting Then AppSetConnectButton(False)
		End Sub
	#tag EndEvent
	#tag Event
		Sub Trace(message As String)
		  AppLog(message)
		End Sub
	#tag EndEvent
	#tag Event
		Sub RawDataReceived(data As String)
		  // options.hexdump in MQTT_Xojo.config.json
		  If AppHexDump() Then AppLog(hexDump(data))
		End Sub
	#tag EndEvent
	#tag Event
		Sub SocketError(err As RuntimeException)
		  // While a reconnection is pending, the Reconnecting line reports the error
		  If MQTTClient1.IsReconnecting Then Return
		  AppLog("Socket " + MQTTClient1.ErrorDescription(err))
		  AppSetConnectButton(False)
		End Sub
	#tag EndEvent
	#tag Event
		Sub MQTTConnected(sessionPresent As Boolean)
		  // Every (re)connection subscribes again (clean session). The first one after a click on Connect
		  // also logs the self-tests and the setup; automatic reconnections only log "Reconnected"
		  Dim firstConnect As Boolean = AppTakeFirstConnect()
		  If Not firstConnect Then AppLog("Reconnected")
		  For i As Integer = 0 To AppTopicCount() - 1
		    Dim packetID As Integer = MQTTClient1.Subscribe(AppTopic(i))
		    AppLog("Connected. Subscribing to " + AppTopic(i) + " (packetID " + Str(packetID) + ")")
		  Next
		  If firstConnect Then
		    AppLog(MeshCryptoSelfTest())
		    AppLog(MeshJSONSelfTest())
		    AppLog(MeshChannelList())
		    SendBoxSetChannels // channel menu of the send row, Send enabled when the node can send
		    If AppHasNode() Then
		      AppLog("Node " + AppNodeID() + " """ + AppNodeLongName() + """ (" + AppNodeShortName() + "): sending enabled")
		      AppLog(MeshPKISelfTest())
		      AppLog(MeshPKIStatus())
		    End If
		  End If
		  // Downlink: announce the app's node on every configured channel, so the mesh shows its name:
		  // at the first connection of a session, then at most once an hour
		  If AppHasNode() And AppNodeRoot() <> "" And AppNodeInfoDue() Then
		    Dim userPayload As String = MeshNodeInfoPayload(AppNodeID(), AppNodeLongName(), AppNodeShortName())
		    For c As Integer = 0 To MeshChannelCount() - 1
		      Dim envelope As String
		      Dim problem As String = MeshBuildEnvelope(MeshChannelName(c), AppNodeID(), AppNodeNum(), 4294967295, MeshNewPacketID(), 3, 4, userPayload, envelope)
		      If problem = "" Then
		        Dim nodeInfoTopic As String = AppNodeRoot() + "/2/e/" + MeshChannelName(c) + "/" + AppNodeID()
		        Call AppPublish(nodeInfoTopic, envelope, AppSendQoS(), "NodeInfo")
		        AppLog("  NodeInfo -> " + nodeInfoTopic)
		      Else
		        AppLog("  NodeInfo on " + MeshChannelName(c) + " failed: " + problem)
		      End If
		    Next
		  End If
		  
		End Sub
	#tag EndEvent
	#tag Event
		Sub MessageReceived(topic As String, payload As String, qos As Integer, retained As Boolean)
		  // Meshtastic packets: one line per packet, and the converter's JSON republished on .../2/json/...
		  // JSON arriving on a /2/json/ topic (including our own) is shown as it is, not decoded again
		  Dim jsonText, packetKey As String
		  Dim summary As String
		  If topic.IndexOf("/2/json/") < 0 Then summary = MeshPacketSummary(payload, jsonText, packetKey)
		  If summary <> "" Then
		    // options.dedupe: a packet already seen (same sender and id) is neither shown nor republished
		    If AppDedupe() And MeshSeenRecently(packetKey) Then Return
		    AppLog(summary)
		    AppCheckRouting // after the packet line: an ACK / NAK for one of our direct messages
		    AppAnswerAckRequest // a message to our node that asks for an ACK
		    If jsonText <> "" And topic.IndexOf("/2/e/") >= 0 Then
		      Dim jsonTopic As String = topic.Replace("/2/e/", "/2/json/")
		      Call AppPublish(jsonTopic, jsonText, AppJSONQoS(), "") // QoS 1 JSON: only failures are logged
		      AppLog("  JSON -> " + jsonTopic + ": " + jsonText)
		    End If
		  Else
		    AppLog(topic + ": " + payload)
		    // Downlink: a "send..." JSON on .../2/json/<channel>/... becomes a protobuf packet on .../2/e/<channel>/<node id>
		    If AppHasNode() And topic.IndexOf("/2/json/") >= 0 Then
		      Dim outTopic, outPayload, info As String
		      Dim sentID, sentTo As UInt32
		      Dim ackRequested As Boolean
		      If MeshDownlink(topic, payload, AppNodeNum(), AppNodeID(), outTopic, outPayload, info, sentID, sentTo, ackRequested) Then
		        Call AppPublish(outTopic, outPayload, AppSendQoS(), "SEND")
		        AppLog("  SEND -> " + outTopic + " (QoS " + Str(AppSendQoS()) + "): " + info)
		        If ackRequested Then AppExpectAck(sentID, sentTo, "DM to " + MeshNodeID(sentTo))
		      ElseIf info <> "" Then
		        AppLog("  SEND failed: " + info)
		      End If
		    End If
		  End If
		  
		End Sub
	#tag EndEvent
	#tag Event
		Sub PublishAcknowledged(packetID As Integer)
		  // The broker confirmed a QoS 1 publish (the broker, not the mesh). Logged for sends and NodeInfo only
		  Dim label As String = AppTakePublishLabel(packetID)
		  If label <> "" Then AppLog("  " + label + " confirmed by the broker (packet " + Str(packetID) + ")")
		End Sub
	#tag EndEvent
	#tag Event
		Sub PublishFailed(packetID As Integer, reason As String)
		  Dim label As String = AppTakePublishLabel(packetID)
		  If label = "" Then label = "JSON publish"
		  AppLog("  " + label + " " + reason + " (packet " + Str(packetID) + ")")
		End Sub
	#tag EndEvent
#tag EndEvents
#tag Events btConnect
	#tag Event
		Sub Pressed()
		  // Connect / Disconnect toggle: the caption shows what a click does
		  If Me.Caption = "Disconnect" Then
		    MQTTClient1.Disconnect
		    AppLog("Disconnected")
		    AppSetConnectButton(False)
		    Return
		  End If
		  // Broker, topics and channel keys come from MQTT_Xojo.config.json (not in the repository,
		  // see MQTT_Xojo.config.example.json). It is read again at every connect
		  Dim problem As String = AppLoadConfig()
		  If problem <> "" Then
		    AppLog(problem)
		    Return
		  End If
		  AppLog("Configuration: " + AppConfigPath())
		  AppLog("Broker: " + AppBrokerDescription())
		  MQTTClient1.SetTLS(AppTLS(), AppTLSConnectionType())
		  If AppTLS() Then AppLog("Note: the broker's certificate is not verified (Xojo SSLSocket limitation): TLS protects against eavesdropping, not against impersonation")
		  MQTTClient1.SetCredentials(AppUsername(), AppPassword())
		  MQTTClient1.SetAutoReconnect(AppReconnect(), AppReconnectMaxDelay(), AppReconnectGiveUp())
		  AppStartSession
		  AppSetConnectButton(True) // back to "Connect" when the connection ends for good
		  MQTTClient1.Connect(AppHost(), AppPort(), AppClientID())
		End Sub
	#tag EndEvent
#tag EndEvents
#tag Events btClear
	#tag Event
		Sub Pressed()
		  MessagesArea.Text = ""
		  AppResetLogStart // the next saved log starts now
		  
		End Sub
	#tag EndEvent
#tag EndEvents
#tag Events btSave
	#tag Event
		Sub Pressed()
		  // Saves the log where the user chooses (file name with date and time, header with the time span); the log stays
		  Dim status As String
		  status = AppSaveLog(MessagesArea.Text)
		  AppLog(status)
		  
		End Sub
	#tag EndEvent
#tag EndEvents
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
		Name="Interfaces"
		Visible=true
		Group="ID"
		InitialValue=""
		Type="String"
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
		Name="Width"
		Visible=true
		Group="Size"
		InitialValue="600"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Height"
		Visible=true
		Group="Size"
		InitialValue="400"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MinimumWidth"
		Visible=true
		Group="Size"
		InitialValue="64"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MinimumHeight"
		Visible=true
		Group="Size"
		InitialValue="64"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MaximumWidth"
		Visible=true
		Group="Size"
		InitialValue="32000"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MaximumHeight"
		Visible=true
		Group="Size"
		InitialValue="32000"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Type"
		Visible=true
		Group="Frame"
		InitialValue="0"
		Type="Types"
		EditorType="Enum"
		#tag EnumValues
			"0 - Document"
			"1 - Movable Modal"
			"2 - Modal Dialog"
			"3 - Floating Window"
			"4 - Plain Box"
			"5 - Shadowed Box"
			"6 - Rounded Window"
			"7 - Global Floating Window"
			"8 - Sheet Window"
			"9 - Modeless Dialog"
		#tag EndEnumValues
	#tag EndViewProperty
	#tag ViewProperty
		Name="Title"
		Visible=true
		Group="Frame"
		InitialValue="Untitled"
		Type="String"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasCloseButton"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasMaximizeButton"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasMinimizeButton"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasFullScreenButton"
		Visible=true
		Group="Frame"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasTitleBar"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Resizeable"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Composite"
		Visible=false
		Group="OS X (Carbon)"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MacProcID"
		Visible=false
		Group="OS X (Carbon)"
		InitialValue="0"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="FullScreen"
		Visible=true
		Group="Behavior"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="DefaultLocation"
		Visible=true
		Group="Behavior"
		InitialValue="2"
		Type="Locations"
		EditorType="Enum"
		#tag EnumValues
			"0 - Default"
			"1 - Parent Window"
			"2 - Main Screen"
			"3 - Parent Window Screen"
			"4 - Stagger"
		#tag EndEnumValues
	#tag EndViewProperty
	#tag ViewProperty
		Name="Visible"
		Visible=true
		Group="Behavior"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="ImplicitInstance"
		Visible=true
		Group="Window Behavior"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasBackgroundColor"
		Visible=true
		Group="Background"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="BackgroundColor"
		Visible=true
		Group="Background"
		InitialValue="&cFFFFFF"
		Type="ColorGroup"
		EditorType="ColorGroup"
	#tag EndViewProperty
	#tag ViewProperty
		Name="Backdrop"
		Visible=true
		Group="Background"
		InitialValue=""
		Type="Picture"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MenuBar"
		Visible=true
		Group="Menus"
		InitialValue=""
		Type="DesktopMenuBar"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MenuBarVisible"
		Visible=true
		Group="Deprecated"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
#tag EndViewBehavior
