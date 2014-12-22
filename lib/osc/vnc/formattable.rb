module OSC::VNC::Formattable

  # Output in Java jnlp format
  def to_jnlp()
    <<-EOF.gsub /^\s{6}/, ''
      <?xml version="1.0" encoding="UTF-8"?>
      <jnlp spec="1.0+" codebase="http://mirror.osc.edu/mirror" >
          <information>
              <title>TightVnc Viewer</title>
              <vendor>GlavSoft LLC.</vendor>
              <offline-allowed/>
          </information>
          <security>
              <all-permissions/>
          </security>
          <resources>
              <j2se version="1.6+"/>
              <jar href="TightVncViewerSigned.jar" main="true"/>
          </resources>
          <application-desc main-class="com.tightvnc.vncviewer.VncViewer">
              <argument>HOST</argument>
              <argument>#{host}</argument>
              <argument>PORT</argument>
              <argument>#{port}</argument>
              <argument>PASSWORD</argument>
              <argument>#{password}</argument>
          </application-desc>
      </jnlp>
    EOF
  end

end
