table! {
    checks (id) {
        id -> Integer,
        updated -> Timestamp,
        up -> Bool,
        instance_id -> Integer,
    }
}

table! {
    instances (id) {
        id -> Integer,
        url -> Text,
        version -> Text,
        https -> Bool,
        https_redirect -> Bool,
        country_id -> Text,
        attachments -> Bool,
    }
}

joinable!(checks -> instances (instance_id));

allow_tables_to_appear_in_same_query!(
    checks,
    instances,
);
