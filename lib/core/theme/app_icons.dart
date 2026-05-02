import 'package:flutter/material.dart';

/// Single source of truth for every icon used in the app.
///
/// All entries prefer `_rounded` variants for visual consistency on mobile.
/// Non-rounded variants that existed at the audit callsites have been upgraded
/// to their rounded equivalents here.
///
/// Usage:
/// ```dart
/// import 'package:flight_path/core/theme/app_icons.dart';
/// Icon(AppIcons.home)
/// ```
abstract final class AppIcons {
  // ---------------------------------------------------------------------------
  // Navigation tabs
  // ---------------------------------------------------------------------------
  static const home = Icons.home_rounded;
  static const homeOutlined = Icons.home_outlined;
  static const exercises = Icons.list_rounded;
  static const exercisesOutlined = Icons.list_outlined;
  static const logbook = Icons.bar_chart_rounded;
  static const logbookOutlined = Icons.bar_chart_outlined;
  static const learn = Icons.school_rounded;
  static const learnOutlined = Icons.school_outlined;
  static const tools = Icons.handyman_rounded;
  static const toolsOutlined = Icons.handyman_outlined;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  static const add = Icons.add_rounded;
  static const remove = Icons.remove_rounded;
  static const edit = Icons.edit_rounded;
  static const editNote = Icons.edit_note_rounded;
  static const editCalendar = Icons.edit_calendar_rounded;
  static const delete = Icons.delete_rounded;
  static const deleteOutline = Icons.delete_outline_rounded;
  static const deleteForever = Icons.delete_forever_rounded;
  static const save = Icons.save_rounded;
  static const send = Icons.send_rounded;
  static const back = Icons.arrow_back_rounded;
  static const forward = Icons.arrow_forward_rounded;
  static const arrowRight = Icons.arrow_right_rounded;
  static const arrowUp = Icons.arrow_upward_rounded;
  static const arrowDown = Icons.arrow_downward_rounded;
  static const arrowDropDown = Icons.arrow_drop_down_rounded;
  static const chevronLeft = Icons.chevron_left_rounded;
  static const chevronRight = Icons.chevron_right_rounded;
  static const close = Icons.close_rounded;
  static const clear = Icons.clear_rounded;
  static const cancel = Icons.cancel_rounded;
  static const more = Icons.more_vert_rounded;
  static const settings = Icons.settings_rounded;
  static const search = Icons.search_rounded;
  static const searchOff = Icons.search_off_rounded;
  static const sort = Icons.sort_rounded;
  static const filter = Icons.sort_rounded; // alias
  static const share = Icons.share_rounded;
  static const shareIos = Icons.ios_share_rounded;
  static const openInNew = Icons.open_in_new;
  static const openInFull = Icons.open_in_full_rounded;
  static const download = Icons.download_rounded;
  static const export_ = Icons.download_rounded; // alias for semantic clarity
  static const pdf = Icons.picture_as_pdf_rounded;
  static const refresh = Icons.refresh_rounded;
  static const restore = Icons.restore_rounded;
  static const repeat = Icons.repeat_rounded;
  static const replay = Icons.replay_rounded;
  static const loop = Icons.loop_rounded;
  static const shuffle = Icons.shuffle_rounded;
  static const play = Icons.play_arrow_rounded;
  static const playCircle = Icons.play_circle_rounded;
  static const playCircleOutline = Icons.play_circle_outline_rounded;
  static const stop = Icons.stop_rounded;
  static const expand = Icons.expand_more_rounded;
  static const collapse = Icons.expand_less_rounded;
  static const link = Icons.link_rounded;
  static const linkOff = Icons.link_off_rounded;
  static const sync = Icons.sync;
  static const cloudUpload = Icons.cloud_upload_outlined;
  static const cloudDownload = Icons.cloud_download_outlined;
  static const cloudDone = Icons.cloud_done;
  static const construction = Icons.construction_rounded;
  static const factCheck = Icons.fact_check_rounded;
  static const highlightOff = Icons.highlight_off_rounded;

  // ---------------------------------------------------------------------------
  // Status / feedback
  // ---------------------------------------------------------------------------
  static const success = Icons.check_circle_rounded;
  static const successOutline = Icons.check_circle_outline_rounded;
  static const check = Icons.check_rounded;
  static const error = Icons.error_outline_rounded;
  static const warning = Icons.warning_amber_rounded;
  static const dangerous = Icons.dangerous_outlined;
  static const info = Icons.info_outline_rounded;
  static const lock = Icons.lock_rounded;
  static const lockOutline = Icons.lock_outline_rounded;
  static const lockReset = Icons.lock_reset_rounded;
  static const premium = Icons.workspace_premium_rounded;
  static const verified = Icons.verified_rounded;
  static const pending = Icons.pending_rounded;
  static const offline = Icons.wifi_off_rounded;
  static const cloud = Icons.cloud_rounded;
  static const cloudOff = Icons.cloud_off_rounded;
  static const doNotDisturb = Icons.do_not_disturb_rounded;

  // ---------------------------------------------------------------------------
  // Features — content & learning
  // ---------------------------------------------------------------------------
  static const flashcard = Icons.style_rounded;
  static const notes = Icons.notes_rounded;
  static const description = Icons.description_outlined;
  static const autoStories = Icons.auto_stories_rounded;
  static const menuBook = Icons.menu_book_rounded;
  static const menuBookOutlined = Icons.menu_book_outlined;
  static const checklist = Icons.checklist_rounded;
  static const formatListNumbered = Icons.format_list_numbered_rounded;
  static const lightbulb = Icons.lightbulb_rounded;
  static const lightbulbOutline = Icons.lightbulb_outline_rounded;
  static const psychology = Icons.psychology_rounded;
  static const ai = Icons.auto_awesome_rounded;
  static const chatBubble = Icons.chat_bubble_rounded;
  static const chatBubbleOutline = Icons.chat_bubble_outline_rounded;
  static const rateReview = Icons.rate_review_rounded;
  static const recordVoiceOver = Icons.record_voice_over_rounded;
  static const radio = Icons.radio_rounded;
  static const radioOutlined = Icons.radio_outlined;
  static const tour = Icons.waving_hand_rounded;
  static const tourOutlined = Icons.tour_outlined;
  static const newReleases = Icons.new_releases_outlined;
  static const accessibility = Icons.accessibility_new_rounded;

  // ---------------------------------------------------------------------------
  // Features — aviation
  // ---------------------------------------------------------------------------
  static const aircraft = Icons.flight_rounded;
  static const aircraftTakeoff = Icons.flight_takeoff_rounded;
  static const aircraftLand = Icons.flight_land_rounded;
  static const airfield = Icons.local_airport_rounded;
  static const route = Icons.route_rounded;
  static const altRoute = Icons.alt_route_rounded;
  static const navigation = Icons.navigation_outlined;
  static const explore = Icons.explore_rounded;
  static const map = Icons.map_rounded;
  static const layers = Icons.layers_rounded;
  static const gps = Icons.gps_fixed_rounded;
  static const locationOff = Icons.location_off_rounded;
  static const forkRight = Icons.fork_right_rounded;
  static const trackChanges = Icons.track_changes_rounded;

  // ---------------------------------------------------------------------------
  // Features — weather & environment
  // ---------------------------------------------------------------------------
  static const weather = Icons.cloud_rounded; // same glyph, explicit alias
  static const metar = Icons.satellite_alt_rounded;
  static const wbCloudy = Icons.wb_cloudy_rounded;
  static const wbSunny = Icons.wb_sunny_rounded;
  static const air = Icons.air_rounded;
  static const thermostat = Icons.thermostat_rounded;
  static const bedtime = Icons.bedtime_rounded;
  static const darkMode = Icons.dark_mode_rounded;
  static const lightMode = Icons.light_mode_rounded;
  static const settingsBrightness = Icons.settings_brightness_rounded;
  static const nightlight = Icons.nightlight_round;

  // ---------------------------------------------------------------------------
  // Features — logbook & progress
  // ---------------------------------------------------------------------------
  static const logbookEntry = Icons.book_outlined;
  static const timeline = Icons.timeline_rounded;
  static const insights = Icons.insights_rounded;
  static const trendingUp = Icons.trending_up_rounded;
  static const trendingDown = Icons.trending_down_rounded;
  static const trendingFlat = Icons.trending_flat_rounded;
  static const barChart = Icons.bar_chart_rounded;
  static const tableChart = Icons.table_chart_rounded;
  static const viewColumn = Icons.view_column_rounded;
  static const speed = Icons.speed_rounded;
  static const calculate = Icons.calculate_rounded;
  static const squareFoot = Icons.square_foot_rounded;
  static const fuel = Icons.local_gas_station_rounded;
  static const bolt = Icons.bolt_rounded;
  static const hourglass = Icons.hourglass_top_rounded;
  static const assignmentDone = Icons.assignment_turned_in_rounded;
  static const eventAvailable = Icons.event_available_rounded;

  // ---------------------------------------------------------------------------
  // Features — voice & audio
  // ---------------------------------------------------------------------------
  static const microphone = Icons.mic_rounded;
  static const microphoneNone = Icons.mic_none_rounded;
  static const atc = Icons.headset_mic_rounded;
  static const volumeUp = Icons.volume_up_rounded;
  static const volumeOff = Icons.volume_off_rounded;

  // ---------------------------------------------------------------------------
  // Features — user & account
  // ---------------------------------------------------------------------------
  static const profile = Icons.person_rounded;
  static const profileOutline = Icons.person_outline_rounded;
  static const people = Icons.people_alt_rounded;
  static const peopleOutline = Icons.people_outline;
  static const signOut = Icons.logout_rounded;
  static const email = Icons.email_rounded;
  static const privacy = Icons.privacy_tip_outlined;
  static const shield = Icons.shield_outlined;
  static const gavel = Icons.gavel_rounded;
  static const palette = Icons.palette_outlined;

  // ---------------------------------------------------------------------------
  // Features — notifications, scheduling & time
  // ---------------------------------------------------------------------------
  static const notification = Icons.notifications_rounded;
  static const notificationActive = Icons.notifications_active_rounded;
  static const timer = Icons.timer_rounded;
  static const timerOutlined = Icons.timer_outlined;
  static const schedule = Icons.schedule;
  static const accessTime = Icons.access_time_rounded;
  static const calendar = Icons.calendar_today_rounded;
  static const calendarOutlined = Icons.calendar_today_outlined;
  static const calendarMonth = Icons.calendar_month_rounded;
  static const dateRange = Icons.date_range_rounded;
  static const eventNote = Icons.event_note_rounded;
  static const eventRepeat = Icons.event_repeat_rounded;

  // ---------------------------------------------------------------------------
  // Features — ratings, rewards & streaks
  // ---------------------------------------------------------------------------
  static const rating = Icons.star_outline_rounded;
  static const ratingFilled = Icons.star_rounded;
  static const emojiEvents = Icons.emoji_events_rounded;
  static const militaryTech = Icons.military_tech_rounded;
  static const fire = Icons.local_fire_department_rounded;
  static const whatshot = Icons.whatshot;

  // ---------------------------------------------------------------------------
  // Misc / UI primitives
  // ---------------------------------------------------------------------------
  static const help = Icons.help_outline_rounded;
  static const history = Icons.history_rounded;
  static const visibility = Icons.visibility_rounded;
  static const visibilityOutlined = Icons.visibility_outlined;
  static const visibilityOff = Icons.visibility_off_outlined;
  static const radioButtonChecked = Icons.radio_button_checked;
  static const radioButtonUnchecked = Icons.radio_button_unchecked_rounded;
  static const circle = Icons.circle;
  static const circleOutlined = Icons.circle_outlined;
}
