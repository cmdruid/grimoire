use yaml_rust2::parser::{Event, MarkedEventReceiver, Parser};
use yaml_rust2::scanner::{Marker, TScalarStyle};

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum Value {
    Null,
    Boolean,
    Number(String),
    String(String),
    Sequence(Vec<Value>),
    Mapping(Vec<(String, Value)>),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct YamlFailure {
    pub code: &'static str,
    pub details: Vec<(&'static str, String)>,
}

impl YamlFailure {
    fn plain(code: &'static str) -> Self {
        Self {
            code,
            details: Vec::new(),
        }
    }
}

struct Sink(Vec<Event>);

impl MarkedEventReceiver for Sink {
    fn on_event(&mut self, event: Event, _mark: Marker) {
        self.0.push(event);
    }
}

pub(crate) fn frontmatter(input: &[u8]) -> Result<Value, YamlFailure> {
    let text = std::str::from_utf8(input).map_err(|_| YamlFailure::plain("yaml-malformed"))?;
    let mut lines = text.split_inclusive('\n');
    let opening = lines
        .next()
        .ok_or_else(|| YamlFailure::plain("frontmatter-missing"))?;
    if opening.trim_end_matches(['\r', '\n']) != "---" {
        return Err(YamlFailure::plain("frontmatter-missing"));
    }
    let mut yaml = String::new();
    let mut consumed = opening.len();
    let mut closed = false;
    for line in lines {
        consumed += line.len();
        if consumed > 65_536 {
            return Err(YamlFailure {
                code: "frontmatter-too-large",
                details: vec![
                    ("limit", "65536".into()),
                    ("observed", consumed.to_string()),
                ],
            });
        }
        if line.trim_end_matches(['\r', '\n']) == "---" {
            closed = true;
            break;
        }
        yaml.push_str(line);
    }
    if !closed {
        return Err(YamlFailure::plain("frontmatter-unclosed"));
    }

    let mut sink = Sink(Vec::new());
    Parser::new_from_str(&yaml)
        .load(&mut sink, true)
        .map_err(|_| YamlFailure::plain("yaml-malformed"))?;
    parse_events(&sink.0)
}

fn parse_events(events: &[Event]) -> Result<Value, YamlFailure> {
    let documents = events
        .iter()
        .filter(|event| matches!(event, Event::DocumentStart))
        .count();
    if documents > 1 {
        return Err(YamlFailure::plain("yaml-multiple-documents"));
    }
    let start = events
        .iter()
        .position(|event| matches!(event, Event::DocumentStart))
        .ok_or_else(|| YamlFailure::plain("yaml-malformed"))?
        + 1;
    let mut cursor = start;
    let mut nodes = 0usize;
    parse_value(events, &mut cursor, 0, &mut nodes)
}

fn check_meta(anchor: usize, tagged: bool) -> Result<(), YamlFailure> {
    if anchor != 0 {
        return Err(YamlFailure::plain("yaml-anchor"));
    }
    if tagged {
        return Err(YamlFailure::plain("yaml-tag"));
    }
    Ok(())
}

fn add_node(nodes: &mut usize) -> Result<(), YamlFailure> {
    *nodes += 1;
    if *nodes > 4_096 {
        return Err(YamlFailure {
            code: "yaml-node-limit",
            details: vec![("limit", "4096".into()), ("observed", nodes.to_string())],
        });
    }
    Ok(())
}

fn parse_value(
    events: &[Event],
    cursor: &mut usize,
    depth: usize,
    nodes: &mut usize,
) -> Result<Value, YamlFailure> {
    let event = events
        .get(*cursor)
        .ok_or_else(|| YamlFailure::plain("yaml-malformed"))?;
    *cursor += 1;
    match event {
        Event::Alias(_) => Err(YamlFailure::plain("yaml-alias")),
        Event::Scalar(value, style, anchor, tag) => {
            add_node(nodes)?;
            check_meta(*anchor, tag.is_some())?;
            Ok(parse_scalar(value, *style))
        }
        Event::SequenceStart(anchor, tag) => {
            add_node(nodes)?;
            check_meta(*anchor, tag.is_some())?;
            let next_depth = depth + 1;
            if next_depth > 16 {
                return Err(YamlFailure {
                    code: "yaml-depth-limit",
                    details: vec![("limit", "16".into()), ("observed", next_depth.to_string())],
                });
            }
            let mut values = Vec::new();
            while !matches!(events.get(*cursor), Some(Event::SequenceEnd)) {
                values.push(parse_value(events, cursor, next_depth, nodes)?);
            }
            *cursor += 1;
            Ok(Value::Sequence(values))
        }
        Event::MappingStart(anchor, tag) => {
            add_node(nodes)?;
            check_meta(*anchor, tag.is_some())?;
            let next_depth = depth + 1;
            if next_depth > 16 {
                return Err(YamlFailure {
                    code: "yaml-depth-limit",
                    details: vec![("limit", "16".into()), ("observed", next_depth.to_string())],
                });
            }
            let mut pairs = Vec::new();
            while !matches!(events.get(*cursor), Some(Event::MappingEnd)) {
                let key = match parse_value(events, cursor, next_depth, nodes)? {
                    Value::String(key) => key,
                    _ => return Err(YamlFailure::plain("yaml-non-string-key")),
                };
                if key == "<<" {
                    return Err(YamlFailure::plain("yaml-merge-key"));
                }
                if pairs.iter().any(|(seen, _)| seen == &key) {
                    return Err(YamlFailure {
                        code: "yaml-duplicate-key",
                        details: vec![("key", key)],
                    });
                }
                let value = parse_value(events, cursor, next_depth, nodes)?;
                pairs.push((key, value));
            }
            *cursor += 1;
            Ok(Value::Mapping(pairs))
        }
        _ => Err(YamlFailure::plain("yaml-malformed")),
    }
}

fn parse_scalar(value: &str, style: TScalarStyle) -> Value {
    if style != TScalarStyle::Plain {
        return Value::String(value.to_owned());
    }
    match value {
        "" | "null" | "Null" | "NULL" | "~" => Value::Null,
        "true" | "True" | "TRUE" => Value::Boolean,
        "false" | "False" | "FALSE" => Value::Boolean,
        value if value.parse::<i64>().is_ok() => Value::Number(value.to_owned()),
        value if value.parse::<f64>().is_ok_and(f64::is_finite) => Value::Number(value.to_owned()),
        value => Value::String(value.to_owned()),
    }
}
