#tag Module
Protected Module AppUtils
	#tag Method, Flags = &h0
		Sub AppAckTimerAction(sender As Timer)
		  // Messages without an answer after 2 minutes
		  If mAckLabels = Nil Or mAckLabels.KeyCount = 0 Then
		    sender.RunMode = Timer.RunModes.Off
		    Return
		  End If
		  Dim t As Double = System.Microseconds / 1000000
		  For Each k As Variant In mAckLabels.Keys
		    If t - mAckTimes.Value(k).DoubleValue > 120 Then
		      AppLog("  No acknowledgement for " + mAckLabels.Value(k).StringValue + " within 2 minutes (packet " + k.StringValue + "): it may not have arrived")
		      AppForgetAck(k.StringValue)
		    End If
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AppAnswerAckRequest()
		  // After MeshPacketSummary: a message to our node asked for an ACK (want_ack): answer like a node does,
		  // so the sender's app shows it as delivered
		  Dim fromNode, packetID As UInt32
		  Dim channelName As String
		  If Not MeshTakeAckRequest(fromNode, packetID, channelName) Then Return
		  If Not AppHasNode() Or AppNodeRoot() = "" Or MeshChannelCount() = 0 Then Return
		  If channelName = "" Then channelName = MeshChannelName(0)
		  Dim envelope As String
		  Dim problem As String = MeshBuildAck(channelName, AppNodeID(), AppNodeNum(), fromNode, packetID, envelope)
		  If problem <> "" Then
		    AppLog("  ACK to " + MeshNodeID(fromNode) + " failed: " + problem)
		    Return
		  End If
		  Call AppPublish(AppNodeRoot() + "/2/e/" + channelName + "/" + AppNodeID(), envelope, 0, "")
		  AppLog("  ACK sent to " + MeshNodeID(fromNode) + " for packet " + packetID.ToString)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AppCheckRouting()
		  // After MeshPacketSummary: a ROUTING ACK / NAK for one of our messages ends its wait. Only the destination
		  // sends a real ACK for a direct message (relays send NAKs, e.g. MAX_RETRANSMIT, when they give up)
		  Dim requestID, fromNode, toNode As UInt32
		  Dim errorCode As Integer
		  If Not MeshTakeRouting(requestID, fromNode, toNode, errorCode) Then Return
		  If mAckLabels = Nil Then Return
		  Dim k As String = requestID.ToString
		  If Not mAckLabels.HasKey(k) Then Return
		  Dim label As String = mAckLabels.Value(k).StringValue
		  Dim target As UInt32 = CType(mAckTargets.Value(k).Int64Value, UInt32)
		  If errorCode = 0 And fromNode <> target Then
		    AppLog("  " + label + ": ACK from " + MeshNodeID(fromNode) + ", not the destination; still waiting (packet " + k + ")")
		    Return
		  End If
		  AppForgetAck(k)
		  If errorCode = 0 Then
		    AppLog("  DELIVERED: " + label + " acknowledged by " + MeshNodeID(fromNode) + " (packet " + k + ")")
		  Else
		    AppLog("  NOT DELIVERED: " + label + ": " + MeshRoutingErrorName(errorCode) + " (reported by " + MeshNodeID(fromNode) + ", packet " + k + ")")
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AppExpectAck(packetID As UInt32, toNode As UInt32, label As String)
		  // A message sent with want_ack: wait up to 2 minutes for the destination's ROUTING ACK
		  If mAckLabels = Nil Then
		    mAckLabels = New Dictionary
		    mAckTimes = New Dictionary
		    mAckTargets = New Dictionary
		  End If
		  Dim k As String = packetID.ToString
		  mAckLabels.Value(k) = label
		  mAckTimes.Value(k) = System.Microseconds / 1000000
		  Dim target As Int64 = toNode
		  mAckTargets.Value(k) = target
		  If mAckTimer = Nil Then
		    mAckTimer = New Timer
		    mAckTimer.Period = 10000
		    AddHandler mAckTimer.Action, AddressOf AppAckTimerAction
		  End If
		  mAckTimer.RunMode = Timer.RunModes.Multiple
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AppForgetAck(k As String)
		  mAckLabels.Remove(k)
		  mAckTimes.Remove(k)
		  mAckTargets.Remove(k)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppHasConnected() As Boolean
		  // True once the broker has accepted a connection in this session (since the last click on Connect)
		  Return Not mFirstConnectPending
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AppLog(message As String)
		  // Appends a line to the window's log. The view follows the newest line only when the user is already at
		  // the bottom, so scrolling up to read older lines isn't interrupted by new traffic
		  Dim area As DesktopTextArea = Window1.MessagesArea
		  Dim lastLine As Integer = area.LineNumber(area.Text.Length)
		  // the last visible line: the one at a point just inside the bottom-left corner of the control
		  Dim lastVisible As Integer = area.LineNumber(area.CharacterPosition(4, area.Height - 4))
		  Dim atBottom As Boolean = (lastVisible >= lastLine - 1)
		  area.AddText(message + EndOfLine)
		  If atBottom Then area.VerticalScrollPosition = area.LineNumber(area.Text.Length)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppNodeInfoDue() As Boolean
		  // The NodeInfo goes out at the first connection of a session, then at most once an hour,
		  // so that a flapping connection doesn't spam the mesh (nodes send theirs about every 3 hours)
		  Dim t As Double = System.Microseconds / 1000000
		  If mLastNodeInfo = 0 Or t - mLastNodeInfo >= 3600 Then
		    mLastNodeInfo = t
		    Return True
		  End If
		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppPublish(topic As String, payload As String, qos As Integer, label As String) As Integer
		  // Publishes with the given QoS. For QoS 1 the label ("SEND", "NodeInfo", or "" for JSON) is kept until the
		  // broker confirms (PublishAcknowledged) or the message is lost (PublishFailed). Returns the packet ID (0 for QoS 0)
		  If qos <> 1 Then
		    Window1.MQTTClient1.Publish(topic, payload)
		    Return 0
		  End If
		  Dim packetID As Integer = Window1.MQTTClient1.PublishQoS1(topic, payload)
		  If packetID > 0 Then
		    If mPublishLabels = Nil Then mPublishLabels = New Dictionary
		    mPublishLabels.Value(packetID) = label
		  End If
		  Return packetID
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AppResetLogStart()
		  // The log in the window starts (again) now: at app start, Clear and Save
		  mLogStarted = DateTime.Now
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppSaveLog(logText As String) As String
		  // Asks where to save the log (default name with the date and time) and writes it with a header giving the
		  // time span it covers (since the window opened or the last Clear). Returns the status line to show
		  Dim savedAt As DateTime = DateTime.Now
		  If mLogStarted = Nil Then mLogStarted = savedAt
		  Dim stamp As String = savedAt.SQLDateTime
		  stamp = stamp.ReplaceAll(":", "-")
		  Dim f As FolderItem = FolderItem.ShowSaveFileDialog("", "MQTT_Xojo log " + stamp + ".txt")
		  If f = Nil Then Return "Save cancelled"
		  Dim header() As String
		  header.Add("MQTT_Xojo log")
		  header.Add("Log started: " + AppTimeStamp(mLogStarted))
		  header.Add("Log saved:   " + AppTimeStamp(savedAt))
		  If AppConfigPath() <> "" Then header.Add("Configuration: " + AppConfigPath())
		  If AppHost() <> "" Then header.Add("Broker: " + AppBrokerDescription())
		  header.Add("----------------------------------------------------------------")
		  Dim body As String = logText.ReplaceLineEndings(EndOfLine)
		  Try
		    Dim stream As TextOutputStream = TextOutputStream.Create(f)
		    stream.Encoding = Encodings.UTF8
		    stream.Write(String.FromArray(header, EndOfLine) + EndOfLine + body)
		    stream.Close
		  Catch err As IOException
		    Return "Could not save the log to " + f.NativePath + ": " + err.Message
		  End Try
		  Return "Log saved to " + f.NativePath + " (" + AppTimeStamp(mLogStarted) + " to " + AppTimeStamp(savedAt) + ")"
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AppSetConnectButton(active As Boolean)
		  // The connect button toggles: "Disconnect" while connecting or connected, "Connect" once the connection has ended
		  If active Then
		    Window1.btConnect.Caption = "Disconnect"
		  Else
		    Window1.btConnect.Caption = "Connect"
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AppStartSession()
		  // A click on Connect: the next MQTTConnected is the first of the session, and the NodeInfo is due
		  mFirstConnectPending = True
		  mLastNodeInfo = 0
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppTakeFirstConnect() As Boolean
		  // True for the first MQTTConnected after a click on Connect, False for automatic reconnections
		  Dim isFirst As Boolean = mFirstConnectPending
		  mFirstConnectPending = False
		  Return isFirst
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppTakePublishLabel(packetID As Integer) As String
		  // The label of a QoS 1 publish, removed once used ("" if unknown)
		  If mPublishLabels = Nil Then Return ""
		  If Not mPublishLabels.HasKey(packetID) Then Return ""
		  Dim label As String = mPublishLabels.Value(packetID).StringValue
		  mPublishLabels.Remove(packetID)
		  Return label
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function AppTimeStamp(d As DateTime) As String
		  // "2026-10-01 20:15:32 UTC+08:00": local time with its offset, so saved logs stay unambiguous
		  Dim offset As Integer = d.Timezone.SecondsFromGMT
		  Dim sign As String = "+"
		  If offset < 0 Then sign = "-"
		  Dim minutes As Integer = Abs(offset) \ 60
		  Dim hh As String = "0" + Str(minutes \ 60)
		  Dim mm As String = "0" + Str(minutes Mod 60)
		  Return d.SQLDateTime + " UTC" + sign + hh.Right(2) + ":" + mm.Right(2)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function hexDump(mb As MemoryBlock) As String
		  If mb = Nil Then Return ""
		  Dim ln, cm, s, result As String
		  Dim ix, n As Integer
		  result = "    +------------------------------------------------+ +----------------+" + EndOfLine
		  result = result + "    |.0 .1 .2 .3 .4 .5 .6 .7 .8 .9 .a .b .c .d .e .f | |      ASCII     |" + EndOfLine
		  result = result + "    +------------------------------------------------+ +----------------+" + EndOfLine
		  
		  n = mb.UInt8Value(0)
		  s = "0"+Hex(n)
		  ln = "000.|"+s.RightBytes(2)+" "
		  If n<32 Or n>127 Then
		    cm = "."
		  Else
		    cm = Chr(n)
		  End If
		  ix = 1
		  While ix<mb.Size
		    If ix mod 16 = 0 Then
		      result = result + ln+ "| |" + cm + "|" + EndOfLine
		      ln = Hex(ix \ 16)
		      While ln.Length < 3
		        ln = "0" + ln
		      Wend
		      ln = ln + ".|"
		      cm = ""
		    End If
		    n = mb.UInt8Value(ix)
		    s = "0"+Hex(n)
		    ln = ln+s.RightBytes(2)+" "
		    If n<32 Or n>127 Then
		      cm = cm+"."
		    Else
		      cm = cm+Chr(n)
		    End If
		    ix = ix+1
		  Wend
		  While ln.Length<51
		    ln = ln+"   "
		    cm = cm+" "
		  Wend
		  result = result + ln+"| |"+cm+"|" + EndOfLine
		  result = result +  "    +------------------------------------------------+ +----------------+" + EndOfLine
		  Return result
		  
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mAckLabels As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mAckTargets As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mAckTimer As Timer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mAckTimes As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mFirstConnectPending As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLastNodeInfo As Double
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogStarted As DateTime
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPublishLabels As Dictionary
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
