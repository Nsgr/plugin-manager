class PluginListTab : ITab
{
	Net::HttpRequest@ m_request;

	bool m_error = false;
	string m_errorMessage;

	int m_total;
	int m_page;
	int m_pageCount;
	array<PluginInfo@> m_plugins;

	bool IsVisible() { return true; }
	bool CanClose() { return false; }

	string GetLabel() { return "Plugins"; }

	void GetRequestTags(array<string>@ tags)
	{
		tags.InsertLast("Modern");

#if TMNEXT || MPD
		tags.InsertLast("Trackmania");
#elif TURBO
		tags.InsertLast("Turbo");
#else
		tags.InsertLast("Maniaplanet");
#endif
	}

	void GetRequestParams(dictionary@ params)
	{
		array<string> tags;
		GetRequestTags(tags);

		string paramTags = "";
		for (uint i = 0; i < tags.Length; i++) {
			if (i > 0) {
				paramTags += ",";
			}
			paramTags += tags[i];
		}

		params.Set("tags", paramTags);
	}

	void Clear()
	{
		m_error = false;
		m_errorMessage = "";

		m_total = 0;
		m_page = 0;
		m_pageCount = 0;
		m_plugins.RemoveRange(0, m_plugins.Length);
	}

	void StartRequest()
	{
		Clear();

		dictionary params;
		GetRequestParams(params);

		string urlParams = "";
		if (!params.IsEmpty()) {
			auto keys = params.GetKeys();
			for (uint i = 0; i < keys.Length; i++) {
				string key = keys[i];
				string value;
				params.Get(key, value);

				urlParams += (i == 0 ? "?" : "&");
				urlParams += key + "=" + Net::UrlEncode(value);
			}
		}

		@m_request = API::Get("files" + urlParams);
	}

	void CheckStartRequest()
	{
		// If there's not already a request and the window is appearing, we start a new request
		if (m_request is null && UI::IsWindowAppearing()) {
			StartRequest();
		}
	}

	void CheckRequest()
	{
		CheckStartRequest();

		// If there's a request, check if it has finished
		if (m_request !is null && m_request.Finished()) {
			// Parse the response
			string res = m_request.String();
			@m_request = null;
			auto js = Json::Parse(res);

			// Handle the response
			if (js.HasKey("error")) {
				HandleErrorResponse(js["error"]);
			} else {
				HandleResponse(js);
			}
		}
	}

	void HandleResponse(const Json::Value &in js)
	{
		m_total = js["total"];
		m_page = js["page"];
		m_pageCount = js["pages"];

		auto jsItems = js["items"];
		for (uint i = 0; i < jsItems.Length; i++) {
			m_plugins.InsertLast(PluginInfo(jsItems[i]));
		}
	}

	void HandleErrorResponse(const string &in message)
	{
		m_error = true;
		m_errorMessage = message;

		error("Unable to get plugin list: " + message);
	}

	void Render()
	{
		CheckRequest();

		if (m_request !is null) {
			UI::Text("Loading list..");
			return;
		}

		if (m_error) {
			UI::Text("\\$f77" + Icons::ExclamationTriangle + "\\$z Unable to get plugin list! " + m_errorMessage);
			return;
		}

		if (UI::BeginTable("Plugins", Setting_PluginsPerRow, UI::TableColumnFlags::WidthStretch)) {
			const float WINDOW_PADDING = 8;
			const float COL_SPACING = 4;
			float colWidth = (UI::GetWindowSize().x - WINDOW_PADDING * 2 - COL_SPACING * (Setting_PluginsPerRow - 1)) / float(Setting_PluginsPerRow);
			for (uint i = 0; i < m_plugins.Length; i++) {
				UI::TableNextColumn();
				Controls::PluginCard(m_plugins[i], colWidth);
			}
			UI::EndTable();
		}
	}
}