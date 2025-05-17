from django.db import models
from django.conf import settings

class ScheduleItem(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    event_name = models.CharField(max_length=255)
    start_time = models.TimeField()
    end_time = models.TimeField()
    day_of_week = models.IntegerField(
        choices=[
            (0, 'Sunday'),
            (1, 'Monday'),
            (2, 'Tuesday'),
            (3, 'Wednesday'),
            (4, 'Thursday'),
            (5, 'Friday'),
            (6, 'Saturday'),
        ]
    )

    def __str__(self):
        return f"{self.event_name} on {self.get_day_of_week_display()} from {self.start_time} to {self.end_time}"
