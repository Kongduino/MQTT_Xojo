#tag Module
Protected Module SendBox
	#tag Method, Flags = &h0
		Sub SendBoxCreate(w As DesktopWindow, area As DesktopTextArea)
		  // The send row under the messages area: To (empty = broadcast), channel, message, Send.
		  // The controls are created in code (DesktopWindow.AddControl), so the window layout needs no changes
		  Dim rowHeight As Integer = 22
		  area.Height = area.Height - (rowHeight + 12)
		  Dim rowTop As Integer = area.Top + area.Height + 10
		  
		  mToField = New DesktopTextField
		  mToField.Left = area.Left
		  mToField.Top = rowTop
		  mToField.Width = 110
		  mToField.Height = rowHeight
		  mToField.Hint = "To: empty = all"
		  mToField.Tooltip = "Recipient: !aabbccdd for a direct message (PKI when its public key is known), empty for a broadcast"
		  mToField.LockLeft = True
		  mToField.LockTop = False
		  mToField.LockBottom = True
		  mToField.Visible = True
		  mToField.Enabled = True
		  w.AddControl(mToField)
		  
		  mChannelMenu = New DesktopPopupMenu
		  mChannelMenu.Left = mToField.Left + mToField.Width + 8
		  mChannelMenu.Top = rowTop
		  mChannelMenu.Width = 130
		  mChannelMenu.Height = rowHeight
		  mChannelMenu.Tooltip = "Channel for broadcasts and channel-key messages (PKI direct messages ignore it)"
		  mChannelMenu.LockLeft = True
		  mChannelMenu.LockTop = False
		  mChannelMenu.LockBottom = True
		  mChannelMenu.Visible = True
		  mChannelMenu.Enabled = True
		  w.AddControl(mChannelMenu)
		  
		  mSendButton = New DesktopButton
		  mSendButton.Caption = "Send"
		  mSendButton.Width = 80
		  mSendButton.Height = rowHeight
		  mSendButton.Left = area.Left + area.Width - mSendButton.Width
		  mSendButton.Top = rowTop
		  mSendButton.LockLeft = False
		  mSendButton.LockRight = True
		  mSendButton.LockTop = False
		  mSendButton.LockBottom = True
		  mSendButton.Visible = True
		  mSendButton.Enabled = False
		  AddHandler mSendButton.Pressed, AddressOf SendBoxPressed
		  w.AddControl(mSendButton)
		  
		  mMessageField = New DesktopTextField
		  mMessageField.Left = mChannelMenu.Left + mChannelMenu.Width + 8
		  mMessageField.Top = rowTop
		  mMessageField.Width = mSendButton.Left - 8 - mMessageField.Left
		  mMessageField.Height = rowHeight
		  mMessageField.Hint = "Message"
		  mMessageField.LockLeft = True
		  mMessageField.LockRight = True
		  mMessageField.LockTop = False
		  mMessageField.LockBottom = True
		  mMessageField.Visible = True
		  mMessageField.Enabled = True
		  AddHandler mMessageField.KeyDown, AddressOf SendBoxKeyDown
		  w.AddControl(mMessageField)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function SendBoxKeyDown(sender As DesktopTextField, key As String) As Boolean
		  // Return or Enter in the message field sends
		  If key = Chr(13) Or key = Chr(3) Then
		    If mSendButton.Enabled Then SendBoxSend
		    Return True
		  End If
		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SendBoxPressed(sender As DesktopButton)
		  SendBoxSend
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SendBoxReport(message As String)
		  AppLog(message)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SendBoxSend()
		  // Sends the message the same way a JSON request on <root>/2/json/<channel>/... is handled (MeshDownlink),
		  // so direct messages to nodes with a known public key go PKI-encrypted
		  Dim text As String = mMessageField.Text.Trim
		  If text = "" Then Return
		  If Not Window1.MQTTClient1.IsMQTTConnected Then
		    SendBoxReport("  SEND failed: not connected")
		    Return
		  End If
		  If Not AppHasNode() Or AppNodeRoot() = "" Then
		    SendBoxReport("  SEND failed: sending needs node.id and node.root in MQTT_Xojo.config.json")
		    Return
		  End If
		  If mChannelMenu.SelectedRowIndex < 0 Then
		    SendBoxReport("  SEND failed: no channel selected")
		    Return
		  End If
		  Dim request As New JSONItem
		  request.Value("type") = "sendtext"
		  request.Value("payload") = text
		  Dim recipient As String = mToField.Text.Trim
		  If recipient <> "" Then request.Value("to") = recipient
		  Dim channelName As String = mChannelMenu.RowTextAt(mChannelMenu.SelectedRowIndex)
		  Dim requestTopic As String = AppNodeRoot() + "/2/json/" + channelName + "/ui"
		  Dim outTopic, outPayload, info As String
		  Dim sentID, sentTo As UInt32
		  Dim ackRequested As Boolean
		  If MeshDownlink(requestTopic, request.ToString, AppNodeNum(), AppNodeID(), outTopic, outPayload, info, sentID, sentTo, ackRequested) Then
		    Call AppPublish(outTopic, outPayload, AppSendQoS(), "SEND")
		    SendBoxReport("  SEND -> " + outTopic + " (QoS " + Str(AppSendQoS()) + "): " + info)
		    If ackRequested Then AppExpectAck(sentID, sentTo, "DM to " + MeshNodeID(sentTo))
		    mMessageField.Text = ""
		  Else
		    If info = "" Then info = "not sent"
		    SendBoxReport("  SEND failed: " + info)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SendBoxSetChannels()
		  // Fills the channel menu with the configured channels and enables Send when the node can send (after connect)
		  If mChannelMenu = Nil Then Return
		  mChannelMenu.RemoveAllRows
		  For c As Integer = 0 To MeshChannelCount() - 1
		    mChannelMenu.AddRow(MeshChannelName(c))
		  Next
		  If mChannelMenu.RowCount > 0 Then mChannelMenu.SelectedRowIndex = 0
		  mSendButton.Enabled = AppHasNode() And AppNodeRoot() <> "" And mChannelMenu.RowCount > 0
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mChannelMenu As DesktopPopupMenu
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mMessageField As DesktopTextField
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mSendButton As DesktopButton
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mToField As DesktopTextField
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
