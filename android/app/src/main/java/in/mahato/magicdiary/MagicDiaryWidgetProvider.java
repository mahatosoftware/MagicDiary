package in.mahato.magicdiary;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import android.widget.RemoteViews;

import es.antonborri.home_widget.HomeWidgetLaunchIntent;
import es.antonborri.home_widget.HomeWidgetProvider;

public class MagicDiaryWidgetProvider extends HomeWidgetProvider {

    @Override
    public void onUpdate(
            Context context,
            AppWidgetManager appWidgetManager,
            int[] appWidgetIds,
            SharedPreferences widgetData
    ) {
        for (int appWidgetId : appWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.magic_diary_widget);

            // Container click -> open app
            PendingIntent openAppIntent = HomeWidgetLaunchIntent.INSTANCE.getActivity(
                    context,
                    MainActivity.class,
                    Uri.parse("magicdiary://home")
            );
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent);

            // Set dynamic texts from Flutter widgetData
            String title = widgetData.getString("widget_title", "Magic Diary 📔");
            String date = widgetData.getString("widget_date", "Today");
            String pendingBills = widgetData.getString("pending_bills", "No pending bills");
            String pendingReminders = widgetData.getString("pending_reminders", "All tasks caught up");

            views.setTextViewText(R.id.text_widget_title, title);
            views.setTextViewText(R.id.text_widget_date, date);
            views.setTextViewText(R.id.text_pending_bills, pendingBills);
            views.setTextViewText(R.id.text_pending_reminders, pendingReminders);

            // Quick actions with deep links
            PendingIntent addExpenseIntent = HomeWidgetLaunchIntent.INSTANCE.getActivity(
                    context,
                    MainActivity.class,
                    Uri.parse("magicdiary://add-expense")
            );
            views.setOnClickPendingIntent(R.id.btn_quick_expense, addExpenseIntent);

            PendingIntent addNoteIntent = HomeWidgetLaunchIntent.INSTANCE.getActivity(
                    context,
                    MainActivity.class,
                    Uri.parse("magicdiary://add-note")
            );
            views.setOnClickPendingIntent(R.id.btn_quick_note, addNoteIntent);

            PendingIntent billsIntent = HomeWidgetLaunchIntent.INSTANCE.getActivity(
                    context,
                    MainActivity.class,
                    Uri.parse("magicdiary://bills")
            );
            views.setOnClickPendingIntent(R.id.btn_quick_bills, billsIntent);

            PendingIntent meterIntent = HomeWidgetLaunchIntent.INSTANCE.getActivity(
                    context,
                    MainActivity.class,
                    Uri.parse("magicdiary://record-meter")
            );
            views.setOnClickPendingIntent(R.id.btn_quick_meter, meterIntent);

            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }
}
