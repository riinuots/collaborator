# user_assign-------------------------
# Use: To assign users to data access groups on a redcap project with the same user rights as a current user (role). This can add new users or edit existing ones
# role = "[username of user with the desired rights]"
# users.df = Dataframe containing at least 2 columns (username, data_access_group)

# Sources of errors:
#  1. DAG has not been added on REDCap
#  2. Username is not in an acceptable format (e.g. contains spaces, unavaliable characters, etc)
user_assign <- function(redcap_project_uri, redcap_project_token, users.df, role){
  # Load required packages
  require("dplyr")
  require("readr")
  require("RCurl")
  require("stringi")
  require("stringr")
  require("jsonlite")
  "%ni%" <- Negate("%in%")

  user_current <- postForm(
    uri=redcap_project_uri,
    token= redcap_project_token,
    content='user',
    format='csv') %>%
    read_csv()

  user_current %>%
    filter(username == role) %>% # select the user with the desired rights
    dplyr::select(forms) %>% # select form rights
    as.character() %>%
    strsplit(split = ",") %>%
    unlist() %>%
    cbind.data.frame(forms = .) %>%
    separate(forms, c("form", "right"), ":") %>%
    mutate(forms = paste0(as.character(form), ': ', as.character(right))) -> role_forms

  user_current %>%
    filter(username == role) %>% # select the user with the desired rights
    dplyr::select(forms) %>%
    mutate(forms = list(role_forms$forms)) %>%
    dplyr::select(forms) %>%
    toJSON() %>%
    stri_replace_all_fixed(., '[', '') %>%
    stri_replace_all_fixed(., ']', '') %>%
    stri_replace_all_fixed(., '{', '') %>%
    stri_replace_all_fixed(., '\"forms\":', '{') %>%
    stri_replace_all_fixed(., ': ', '": "') %>%
    stri_replace_all_fixed(., ',', ', ') -> role_forms

  user_current %>%
    filter(username == role) %>% # select the user with the desired rights
    dplyr::select(design:lock_records_customization) %>%
    mutate(forms = role_forms) %>%
    jsonlite::toJSON() %>%
    stri_replace_all_fixed(., '}"', '}') %>%
    stri_replace_all_fixed(., '"forms":" ', '"forms":') -> user_rights

  user_rights %>%
    as.character() %>%
    gsub("\\\\", "",.) %>%
    stri_replace_all_fixed(., '"forms\":\"', '"forms\":\ ')  %>%
    prettify() %>%
    as.character() %>%
    substr(., 17, nchar(.[1])) -> user_rights

  users.df = users.df  %>%
    mutate(json = paste0("[{\"username\" :\"", username,
                         "\",\"data_access_group\":\"", data_access_group,
                         "\",", user_rights))

  users.df$json[1] %>%
    prettify() %>%
    print()

  for (i in 1:nrow(users.df)){
    print(i)
    res = try(postForm(
      uri=redcap_project_uri,
      token= redcap_project_token,
      content='user',
      format='json',
      data = users.df$json[i]))

    if (class(res) == "try-error"){
      print(paste('error with: ', as.character(users.df$username[i])))}}
}