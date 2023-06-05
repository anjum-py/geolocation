import os

class ParseEnv:
    def load_dotenv(self):
        """Assuming that the .env file is in the root folder"""

        with open(".env", "r") as file:
            lines = file.readlines()

        for line in lines:
            line = line.strip()
            if line.startswith("#") or not line:
                continue

            key, value = line.split("=", 1)
            value = value.strip()

            value = self.substitute_variables(value)

            os.environ[key] = value

    def substitute_variables(self, value):
        start_pos = 0
        while True:
            start_var = value.find("${", start_pos)
            if start_var == -1:
                break

            end_var = value.find("}", start_var)
            if end_var == -1:
                break

            variable_name = value[start_var + 2 : end_var]
            variable_value = os.environ.get(variable_name, "")
            value = value[:start_var] + variable_value + value[end_var + 1 :]
            start_pos = start_var + len(variable_value)

        return value

    def getenv(self, key, default=None):
        value = os.environ.get(key, default)
        if not value or "$" in value:
            self.load_dotenv()
            value = os.environ.get(key, default)
        return value.replace('"', '').strip()

getenv = ParseEnv().getenv
