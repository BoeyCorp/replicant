import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../replicant.js" as R

// The top of a list tab: a search field, "Collapse all", the filters, and the
// legend of the badges. Configs and Settings use the same one, in the same
// order, so a person finds each part in the same place on both tabs.
Column {
  id: fb
  // The panel this belongs to. Every value and every action comes from it.
  property var panel
  property string placeholder: ""
  property var options: []
  property string value: ""
  property string searchText: ""
  property string legend: ""
  property string collapseTip: ""
  signal searchEdited(string text)
  signal filterPicked(string value)
  function focusSearch() { field.forceActiveFocus() }
  // One search-state contract for keyboard input and programmatic
  // navigation: the panel owns the text, the field mirrors it. User typing
  // emits searchEdited, the panel updates searchText, and the guard below
  // keeps that round-trip from looping. Programmatic clear or chip
  // navigation changes searchText, and the field follows without erasing
  // active typing that already matches.
  onSearchTextChanged: if (R.searchSyncNeedsFieldUpdate(field.text, fb.searchText)) field.text = fb.searchText
  spacing: Style.space(8)

  Row {
    width: parent.width
    spacing: Style.space(8)
    TextField {
      id: field
      objectName: panel.activeTab === "settings" ? "settings-search" : "configs-search"
      width: parent.width - collapseBtn.width - Style.space(8)
      placeholderText: fb.placeholder
      foreground: panel.fg
      accent: Commons.Color.accent
      font.family: panel.ff
      Component.onCompleted: if (R.searchSyncNeedsFieldUpdate(field.text, fb.searchText)) field.text = fb.searchText
      onTextChanged: if (R.searchSyncShouldEmit(field.text, fb.searchText)) fb.searchEdited(field.text)
      onActiveFocusChanged: panel.noteFocus(field, activeFocus)
      Keys.onEscapePressed: { field.text = ""; panel.releaseFocus() }
    }
    Button {
      id: collapseBtn
      text: "Collapse all"; bordered: false
      foreground: panel.dim; fontFamily: panel.ff
      tooltipText: fb.collapseTip
      onClicked: panel.closeAllCards()
    }
  }

  Item {
    width: parent.width
    height: Style.space(34)
    ButtonGroup {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      focusable: true
      spacing: Style.space(4)
      fontSize: Style.font.bodySmall
      foreground: panel.fg
      accent: Commons.Color.accent
      fontFamily: panel.ff
      value: fb.value
      options: fb.options
      onChanged: function(v) { fb.filterPicked(v) }
    }
  }

  // The badges, once. Every row that needs a word says it in words too.
  Text {
    width: parent.width
    text: fb.legend
    color: panel.dim; font.family: panel.ff; font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
