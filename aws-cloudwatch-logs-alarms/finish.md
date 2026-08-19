# Done

You shipped logs off a machine, queried them, turned a pattern into a metric,
and put an alarm on a symptom.

**What you can now do**

- Explain why memory and disk are absent from EC2's default metrics — the
  hypervisor sees the resources it handed out, not what the guest kernel did
  with them — and publish them yourself into a namespace of your own
- Query a log group with CloudWatch's filter syntax, knowing it is term
  matching and not regex, and that a malformed pattern returns silence rather
  than an error
- Build a metric filter so logs drive an alarm instead of waiting to be read
- Justify every argument of a `put-metric-alarm`: the metric, the statistic,
  the evaluation periods, and what missing data means

**What this environment could not show you**

Four gaps, all measured. They are listed because a scenario that hid them would
be teaching you to trust an emulator:

| Behaviour | Real AWS | Here |
| --- | --- | --- |
| `ssm send-command` on an instance | runs, returns output | reports `Success`, runs nothing |
| `--filter-pattern` on a log query | selects events | accepted and ignored |
| Alarm evaluation | state moves to `ALARM` | never evaluates |
| `PutMetricData` into `AWS/EC2` | refused | accepted |

Notice the shape they share: **every one of them is a case where the emulator
says yes.** None of them errors. An API that rejects what it cannot do is easy
to work with; one that accepts everything and does nothing is how you end up
confident about something untrue — the same reason a scan that silently finds
nothing is worse than a scan that fails.

The habit worth taking away is the one step 2 makes you practise: after a query
returns what you expected, run the one that **must** return nothing, and check
that it does. That is the difference between a result and a coincidence, and it
costs one command.

**Next**

The alarm has no action. On a real account that is an SNS topic, and the part
worth testing is the delivery rather than the alarm — a topic with no
subscriber is the usual way a monitoring system turns out to be decorative, and
it is discovered during the incident.
