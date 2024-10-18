module Charai
  class BrowserLauncher
    def initialize
      if ::Charai::Util.macos?
        if File.exist?("/Applications/Firefox Developer Edition.app/Contents/MacOS/firefox")
          @firefox_executable_path = "/Applications/Firefox Developer Edition.app/Contents/MacOS/firefox"
        end
      elsif ::Charai::Util.linux?
        if File.exist?("/usr/bin/firefox-devedition")
          @firefox_executable_path = "/usr/bin/firefox-devedition"
        end
      end

      raise 'Firefox Developer Edition is not found.' unless @firefox_executable_path
    end

    def launch(headless: false, debug_protocol: false)
      tmpdir = Dir.mktmpdir('charai')
      create_user_profile(tmpdir)

      args = [
        "--remote-debugging-port=0",
        "--profile #{tmpdir}",
        "--no-remote",
      ]
      if ::Charai::Util.macos?
        args << "--foreground"
      end
      if headless
        args << "--headless"
      end

      proc = BrowserProcess.new(
        @firefox_executable_path,
        *args,
        "about:blank",
      )
      at_exit do
        proc.kill
        FileUtils.remove_entry(tmpdir)
      end
      trap(:INT) { proc.kill ; exit 130 }
      trap(:TERM) { proc.kill ; proc.dispose }
      trap(:HUP) { proc.kill ; proc.dispose }

      endpoint = wait_for_ws_endpoint(proc)

      web_socket = WebSocket.new(url: "#{endpoint}/session")
      Browser.new(web_socket, debug_protocol: debug_protocol)
    end

    private

    def create_user_profile(profile_dir)
      open(File.join(profile_dir, 'user.js'), 'w') do |f|
        f.write(template_for_user_profile)
      end
    end

    def template_for_user_profile
      # execute the code below to create a template of user profile for Firefox.
      # -----------
      # import { createProfile } from '@puppeteer/browsers';
      #
      # await createProfile('firefox', {
      #   path: './my_prefs',
      #   preferences: {
      #     'remote.active-protocols': 1,
      #     'fission.webContentIsolationStrategy': 0,
      #   }
      # })
      <<~JS
      user_pref("app.normandy.api_url", "");
      user_pref("app.update.checkInstallTime", false);
      user_pref("app.update.disabledForTesting", true);
      user_pref("apz.content_response_timeout", 60000);
      user_pref("browser.contentblocking.features.standard", "-tp,tpPrivate,cookieBehavior0,-cm,-fp");
      user_pref("browser.dom.window.dump.enabled", true);
      user_pref("browser.newtabpage.activity-stream.feeds.system.topstories", false);
      user_pref("browser.newtabpage.enabled", false);
      user_pref("browser.pagethumbnails.capturing_disabled", true);
      user_pref("browser.safebrowsing.blockedURIs.enabled", false);
      user_pref("browser.safebrowsing.downloads.enabled", false);
      user_pref("browser.safebrowsing.malware.enabled", false);
      user_pref("browser.safebrowsing.phishing.enabled", false);
      user_pref("browser.search.update", false);
      user_pref("browser.sessionstore.resume_from_crash", false);
      user_pref("browser.shell.checkDefaultBrowser", false);
      user_pref("browser.startup.homepage", "about:blank");
      user_pref("browser.startup.homepage_override.mstone", "ignore");
      user_pref("browser.startup.page", 0);
      user_pref("browser.tabs.disableBackgroundZombification", false);
      user_pref("browser.tabs.warnOnCloseOtherTabs", false);
      user_pref("browser.tabs.warnOnOpen", false);
      user_pref("browser.translations.automaticallyPopup", false);
      user_pref("browser.uitour.enabled", false);
      user_pref("browser.urlbar.suggest.searches", false);
      user_pref("browser.usedOnWindows10.introURL", "");
      user_pref("browser.warnOnQuit", false);
      user_pref("datareporting.healthreport.documentServerURI", "http://dummy.test/dummy/healthreport/");
      user_pref("datareporting.healthreport.logging.consoleEnabled", false);
      user_pref("datareporting.healthreport.service.enabled", false);
      user_pref("datareporting.healthreport.service.firstRun", false);
      user_pref("datareporting.healthreport.uploadEnabled", false);
      user_pref("datareporting.policy.dataSubmissionEnabled", false);
      user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
      user_pref("devtools.jsonview.enabled", false);
      user_pref("dom.disable_open_during_load", false);
      user_pref("dom.file.createInChild", true);
      user_pref("dom.ipc.reportProcessHangs", false);
      user_pref("dom.max_chrome_script_run_time", 0);
      user_pref("dom.max_script_run_time", 0);
      user_pref("extensions.autoDisableScopes", 0);
      user_pref("extensions.enabledScopes", 5);
      user_pref("extensions.getAddons.cache.enabled", false);
      user_pref("extensions.installDistroAddons", false);
      user_pref("extensions.screenshots.disabled", true);
      user_pref("extensions.update.enabled", false);
      user_pref("extensions.update.notifyUser", false);
      user_pref("extensions.webservice.discoverURL", "http://dummy.test/dummy/discoveryURL");
      user_pref("focusmanager.testmode", true);
      user_pref("general.useragent.updates.enabled", false);
      user_pref("geo.provider.testing", true);
      user_pref("geo.wifi.scan", false);
      user_pref("hangmonitor.timeout", 0);
      user_pref("javascript.options.showInConsole", true);
      user_pref("media.gmp-manager.updateEnabled", false);
      user_pref("media.sanity-test.disabled", true);
      user_pref("network.cookie.sameSite.laxByDefault", false);
      user_pref("network.http.prompt-temp-redirect", false);
      user_pref("network.http.speculative-parallel-limit", 0);
      user_pref("network.manage-offline-status", false);
      user_pref("network.sntp.pools", "dummy.test");
      user_pref("plugin.state.flash", 0);
      user_pref("privacy.trackingprotection.enabled", false);
      user_pref("remote.enabled", true);
      user_pref("security.certerrors.mitm.priming.enabled", false);
      user_pref("security.fileuri.strict_origin_policy", false);
      user_pref("security.notification_enable_delay", 0);
      user_pref("services.settings.server", "http://dummy.test/dummy/blocklist/");
      user_pref("signon.autofillForms", false);
      user_pref("signon.rememberSignons", false);
      user_pref("startup.homepage_welcome_url", "about:blank");
      user_pref("startup.homepage_welcome_url.additional", "");
      user_pref("toolkit.cosmeticAnimations.enabled", false);
      user_pref("toolkit.startup.max_resumed_crashes", -1);
      user_pref("remote.active-protocols", 1);
      user_pref("fission.webContentIsolationStrategy", 0);
      JS
    end

    def wait_for_ws_endpoint(browser_process)
      lines = []
      Timeout.timeout(30) do
        loop do
          line = browser_process.stderr.readline
          /^WebDriver BiDi listening on (ws:\/\/.*)$/.match(line) do |m|
            return m[1].gsub(/\r/, '')
          end
          lines << line
        end
      end
    rescue EOFError
      raise lines.join("\n")
    rescue Timeout::Error
      raise "Timed out after 30 seconds while trying to connect to the browser."
    end
  end
end
