import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../replicant.js" as R

// The values a person changes, one control each, filed under five domains.
// A change is written, applied and committed.
Column {
  id: st
  // The panel this belongs to. Every value and every action comes from it.
  property var panel
  function navigationItem(openCards) {
    for (var d = 0; d < domainRepeater.count; d++) {
      var section = domainRepeater.itemAt(d)
      if (!section) continue
      for (var i = 0; i < section.groupCount; i++) {
        var item = section.groupAt(i)
        if (item && openCards && openCards[item.navigationId]) return item
      }
    }
    return null
  }
  function focusSearch() { filterBar.focusSearch() }
  spacing: Style.space(8)

  FilterBar {
    id: filterBar
    panel: st.panel
    width: st.width
    placeholder: "Filter settings…   (/)"
    options: panel.settingFilterOptions
    value: panel.settingFilter
    legend: "● yours    ○ default    · not here      A change is applied and saved at once."
    collapseTip: "Close every open group  (c)"
    onSearchEdited: function(t) { panel.setSettingSearch(t) }
    onFilterPicked: function(v) { panel.setSettingFilter(v) }
  }

  // Apply manually: some changes take effect only after the shell, Hyprland,
  // or the terminals reload. Fixed below the search, independent of the
  // settings rows, and one action at a time.
  Column {
    width: st.width
    spacing: Style.space(6)
    Text {
      width: parent.width
      text: "Apply manually"
      color: panel.fg; font.family: panel.ff; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    Text {
      width: parent.width
      text: "Some changes take effect only after a reload. Only the shell restart asks first."
      color: panel.dim; font.family: panel.ff; font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
    Row {
      spacing: Style.space(8)
      Button {
        text: "Restart shell"; iconText: panel.icRefresh; bordered: true
        foreground: panel.fg; accent: Commons.Color.accent; fontFamily: panel.ff
        enabled: !panel.applyBusy
        tooltipText: panel.applyBusy ? R.actionDisabledReason({ busy: true }) : "Restart the Omarchy shell. Asks first."
        onClicked: panel.askApplyShell()
      }
      Button {
        text: "Reload Hyprland"; iconText: panel.icRefresh; bordered: true
        foreground: panel.fg; accent: Commons.Color.accent; fontFamily: panel.ff
        enabled: !panel.applyBusy
        tooltipText: panel.applyBusy ? R.actionDisabledReason({ busy: true }) : "Reload the Hyprland configuration now."
        onClicked: panel.doApplyHyprland()
      }
      Button {
        text: "Restart terminals"; iconText: panel.icRefresh; bordered: true
        foreground: panel.fg; accent: Commons.Color.accent; fontFamily: panel.ff
        enabled: !panel.applyBusy
        tooltipText: panel.applyBusy ? R.actionDisabledReason({ busy: true }) : "Reload supported terminals after config changes."
        onClicked: panel.doApplyTerminal()
      }
    }
  }

  Text {
    width: parent.width
    visible: panel.settingsLoading
    text: "Loading settings…"
    color: panel.dim; font.family: panel.ff; font.pixelSize: Style.font.caption
  }

  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: !panel.settingsLoading && panel.settingsError !== ""
    Text {
      width: parent.width
      text: panel.settingsError
      color: panel.warnColor; font.family: panel.ff; font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
    Button {
      text: "Retry"; iconText: panel.icRefresh; bordered: true
      foreground: panel.fg; accent: Commons.Color.accent; fontFamily: panel.ff
      onClicked: panel.retrySettings()
    }
  }

  Text {
    width: parent.width
    visible: !panel.settingsLoading && panel.settingsError === "" && panel.settingGroups.length === 0
    text: panel.settingFilter === "customised" && panel.settingSearch === ""
          ? "Every value is at its default."
          : "Nothing matches that filter."
    color: panel.dim; font.family: panel.ff; font.pixelSize: Style.font.caption
  }

  Repeater {
    id: domainRepeater
    model: panel.settingDomains
    delegate: Column {
      required property var modelData
      property int groupCount: groupRepeater.count
      function groupAt(i) { return groupRepeater.itemAt(i) }
      width: st.width
      spacing: Style.space(8)
      Text {
        width: parent.width
        text: modelData.domain
        color: panel.fg; font.family: panel.ff; font.pixelSize: Style.font.title; font.bold: true
      }
      Repeater {
        id: groupRepeater
        model: modelData.groups
        delegate: SettingCard {
          required property var modelData
          panel: st.panel
          group: modelData
          width: st.width
        }
      }
    }
  }
}
