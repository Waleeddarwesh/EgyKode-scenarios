# Operating an instance you cannot log into

An instance with no inbound ports is the goal. Once you have one, three
questions follow immediately: where do the logs go, what do you measure, and
what is worth waking someone up for.

You will ship application logs into a CloudWatch log group and query them,
publish a memory metric — which EC2 does not give you by default, for a reason
worth understanding — and put an alarm on a symptom rather than on CPU.

## What this scenario does not cover

The lab's first criterion is running a command on the instance with no SSH key
and no inbound rule, through **SSM Run Command**. That needs the SSM agent
running on a real machine and registering itself, and this environment runs
against LocalStack, where an instance is an API record with no operating
system behind it.

It is worth being precise about why that matters here rather than glossing it.
LocalStack *accepts* `ssm send-command` and reports:

```
"Status": "Success",  "ResponseCode": 0,  "StandardOutputContent": ""
```

Success, exit code zero, and no output — because nothing ran. The API that
would reveal the instance was never SSM-managed,
`ssm describe-instance-information`, is not implemented at all. A scenario
built on that would teach you that you had administered a machine you had not
touched.

**So criterion 1 is left to the cloud version of this lab**, on a real account
with a real instance.

Three smaller gaps you will meet as you go, each measured rather than assumed,
and each pointed at in the step where it bites:

| Thing | Here |
| --- | --- |
| Log events stored and retrieved | real |
| Time-bounded queries (`--start-time`) | real |
| `--filter-pattern` | **accepted and ignored** |
| Alarm evaluation | **never runs** |

None of that makes the work fake — you are writing configuration that is
correct for real AWS, and the checks look at what genuinely exists. But it does
mean the environment will happily agree with a query that is wrong, so the
steps show you how to catch it doing that. Learning to tell "accepted" from
"honoured" is worth as much as the CloudWatch syntax.

Setup runs in the background and takes about a minute.
