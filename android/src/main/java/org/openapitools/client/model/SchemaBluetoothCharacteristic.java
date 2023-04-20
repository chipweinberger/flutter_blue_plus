/*
 * Flutter Blue Plus API
 * No description provided (generated by Openapi Generator https://github.com/openapitools/openapi-generator)
 *
 * The version of the OpenAPI document: 1.0.0
 * 
 *
 * NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).
 * https://openapi-generator.tech
 * Do not edit the class manually.
 */


package org.openapitools.client.model;

import java.util.Objects;
import java.util.Arrays;
import com.google.gson.TypeAdapter;
import com.google.gson.annotations.JsonAdapter;
import com.google.gson.annotations.SerializedName;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import org.openapitools.client.model.SchemaBluetoothDescriptor;
import org.openapitools.client.model.SchemaCharacteristicProperties;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.google.gson.TypeAdapterFactory;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;

import org.openapitools.client.JSON;

/**
 * SchemaBluetoothCharacteristic
 */
@javax.annotation.Generated(value = "org.openapitools.codegen.languages.JavaClientCodegen", date = "2023-04-20T01:41:46.146266-07:00[America/Los_Angeles]")
public class SchemaBluetoothCharacteristic {
  public static final String SERIALIZED_NAME_UUID = "uuid";
  @SerializedName(SERIALIZED_NAME_UUID)
  private String uuid;

  public static final String SERIALIZED_NAME_REMOTE_ID = "remote_id";
  @SerializedName(SERIALIZED_NAME_REMOTE_ID)
  private String remoteId;

  public static final String SERIALIZED_NAME_SERVICE_UUID = "serviceUuid";
  @SerializedName(SERIALIZED_NAME_SERVICE_UUID)
  private String serviceUuid;

  public static final String SERIALIZED_NAME_SECONDARY_SERVICE_UUID = "secondaryServiceUuid";
  @SerializedName(SERIALIZED_NAME_SECONDARY_SERVICE_UUID)
  private String secondaryServiceUuid;

  public static final String SERIALIZED_NAME_DESCRIPTORS = "descriptors";
  @SerializedName(SERIALIZED_NAME_DESCRIPTORS)
  private List<SchemaBluetoothDescriptor> descriptors = new ArrayList<>();

  public static final String SERIALIZED_NAME_PROPERTIES = "properties";
  @SerializedName(SERIALIZED_NAME_PROPERTIES)
  private SchemaCharacteristicProperties properties;

  public static final String SERIALIZED_NAME_VALUE = "value";
  @SerializedName(SERIALIZED_NAME_VALUE)
  private byte[] value;

  public SchemaBluetoothCharacteristic() {
  }

  public SchemaBluetoothCharacteristic uuid(String uuid) {
    
    this.uuid = uuid;
    return this;
  }

   /**
   * Get uuid
   * @return uuid
  **/
  @javax.annotation.Nonnull

  public String getUuid() {
    return uuid;
  }


  public void setUuid(String uuid) {
    this.uuid = uuid;
  }


  public SchemaBluetoothCharacteristic remoteId(String remoteId) {
    
    this.remoteId = remoteId;
    return this;
  }

   /**
   * Get remoteId
   * @return remoteId
  **/
  @javax.annotation.Nonnull

  public String getRemoteId() {
    return remoteId;
  }


  public void setRemoteId(String remoteId) {
    this.remoteId = remoteId;
  }


  public SchemaBluetoothCharacteristic serviceUuid(String serviceUuid) {
    
    this.serviceUuid = serviceUuid;
    return this;
  }

   /**
   * Get serviceUuid
   * @return serviceUuid
  **/
  @javax.annotation.Nonnull

  public String getServiceUuid() {
    return serviceUuid;
  }


  public void setServiceUuid(String serviceUuid) {
    this.serviceUuid = serviceUuid;
  }


  public SchemaBluetoothCharacteristic secondaryServiceUuid(String secondaryServiceUuid) {
    
    this.secondaryServiceUuid = secondaryServiceUuid;
    return this;
  }

   /**
   * Get secondaryServiceUuid
   * @return secondaryServiceUuid
  **/
  @javax.annotation.Nonnull

  public String getSecondaryServiceUuid() {
    return secondaryServiceUuid;
  }


  public void setSecondaryServiceUuid(String secondaryServiceUuid) {
    this.secondaryServiceUuid = secondaryServiceUuid;
  }


  public SchemaBluetoothCharacteristic descriptors(List<SchemaBluetoothDescriptor> descriptors) {
    
    this.descriptors = descriptors;
    return this;
  }

  public SchemaBluetoothCharacteristic addDescriptorsItem(SchemaBluetoothDescriptor descriptorsItem) {
    if (this.descriptors == null) {
      this.descriptors = new ArrayList<>();
    }
    this.descriptors.add(descriptorsItem);
    return this;
  }

   /**
   * Get descriptors
   * @return descriptors
  **/
  @javax.annotation.Nonnull

  public List<SchemaBluetoothDescriptor> getDescriptors() {
    return descriptors;
  }


  public void setDescriptors(List<SchemaBluetoothDescriptor> descriptors) {
    this.descriptors = descriptors;
  }


  public SchemaBluetoothCharacteristic properties(SchemaCharacteristicProperties properties) {
    
    this.properties = properties;
    return this;
  }

   /**
   * Get properties
   * @return properties
  **/
  @javax.annotation.Nonnull

  public SchemaCharacteristicProperties getProperties() {
    return properties;
  }


  public void setProperties(SchemaCharacteristicProperties properties) {
    this.properties = properties;
  }


  public SchemaBluetoothCharacteristic value(byte[] value) {
    
    this.value = value;
    return this;
  }

   /**
   * Get value
   * @return value
  **/
  @javax.annotation.Nonnull

  public byte[] getValue() {
    return value;
  }


  public void setValue(byte[] value) {
    this.value = value;
  }



  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }
    if (o == null || getClass() != o.getClass()) {
      return false;
    }
    SchemaBluetoothCharacteristic schemaBluetoothCharacteristic = (SchemaBluetoothCharacteristic) o;
    return Objects.equals(this.uuid, schemaBluetoothCharacteristic.uuid) &&
        Objects.equals(this.remoteId, schemaBluetoothCharacteristic.remoteId) &&
        Objects.equals(this.serviceUuid, schemaBluetoothCharacteristic.serviceUuid) &&
        Objects.equals(this.secondaryServiceUuid, schemaBluetoothCharacteristic.secondaryServiceUuid) &&
        Objects.equals(this.descriptors, schemaBluetoothCharacteristic.descriptors) &&
        Objects.equals(this.properties, schemaBluetoothCharacteristic.properties) &&
        Arrays.equals(this.value, schemaBluetoothCharacteristic.value);
  }

  @Override
  public int hashCode() {
    return Objects.hash(uuid, remoteId, serviceUuid, secondaryServiceUuid, descriptors, properties, Arrays.hashCode(value));
  }

  @Override
  public String toString() {
    StringBuilder sb = new StringBuilder();
    sb.append("class SchemaBluetoothCharacteristic {\n");
    sb.append("    uuid: ").append(toIndentedString(uuid)).append("\n");
    sb.append("    remoteId: ").append(toIndentedString(remoteId)).append("\n");
    sb.append("    serviceUuid: ").append(toIndentedString(serviceUuid)).append("\n");
    sb.append("    secondaryServiceUuid: ").append(toIndentedString(secondaryServiceUuid)).append("\n");
    sb.append("    descriptors: ").append(toIndentedString(descriptors)).append("\n");
    sb.append("    properties: ").append(toIndentedString(properties)).append("\n");
    sb.append("    value: ").append(toIndentedString(value)).append("\n");
    sb.append("}");
    return sb.toString();
  }

  /**
   * Convert the given object to string with each line indented by 4 spaces
   * (except the first line).
   */
  private String toIndentedString(Object o) {
    if (o == null) {
      return "null";
    }
    return o.toString().replace("\n", "\n    ");
  }


  public static HashSet<String> openapiFields;
  public static HashSet<String> openapiRequiredFields;

  static {
    // a set of all properties/fields (JSON key names)
    openapiFields = new HashSet<String>();
    openapiFields.add("uuid");
    openapiFields.add("remote_id");
    openapiFields.add("serviceUuid");
    openapiFields.add("secondaryServiceUuid");
    openapiFields.add("descriptors");
    openapiFields.add("properties");
    openapiFields.add("value");

    // a set of required properties/fields (JSON key names)
    openapiRequiredFields = new HashSet<String>();
    openapiRequiredFields.add("uuid");
    openapiRequiredFields.add("remote_id");
    openapiRequiredFields.add("serviceUuid");
    openapiRequiredFields.add("secondaryServiceUuid");
    openapiRequiredFields.add("descriptors");
    openapiRequiredFields.add("properties");
    openapiRequiredFields.add("value");
  }

 /**
  * Validates the JSON Object and throws an exception if issues found
  *
  * @param jsonObj JSON Object
  * @throws IOException if the JSON Object is invalid with respect to SchemaBluetoothCharacteristic
  */
  public static void validateJsonObject(JsonObject jsonObj) throws IOException {
      if (jsonObj == null) {
        if (!SchemaBluetoothCharacteristic.openapiRequiredFields.isEmpty()) { // has required fields but JSON object is null
          throw new IllegalArgumentException(String.format("The required field(s) %s in SchemaBluetoothCharacteristic is not found in the empty JSON string", SchemaBluetoothCharacteristic.openapiRequiredFields.toString()));
        }
      }

      Set<Entry<String, JsonElement>> entries = jsonObj.entrySet();
      // check to see if the JSON string contains additional fields
      for (Entry<String, JsonElement> entry : entries) {
        if (!SchemaBluetoothCharacteristic.openapiFields.contains(entry.getKey())) {
          throw new IllegalArgumentException(String.format("The field `%s` in the JSON string is not defined in the `SchemaBluetoothCharacteristic` properties. JSON: %s", entry.getKey(), jsonObj.toString()));
        }
      }

      // check to make sure all required properties/fields are present in the JSON string
      for (String requiredField : SchemaBluetoothCharacteristic.openapiRequiredFields) {
        if (jsonObj.get(requiredField) == null) {
          throw new IllegalArgumentException(String.format("The required field `%s` is not found in the JSON string: %s", requiredField, jsonObj.toString()));
        }
      }
      if (!jsonObj.get("uuid").isJsonPrimitive()) {
        throw new IllegalArgumentException(String.format("Expected the field `uuid` to be a primitive type in the JSON string but got `%s`", jsonObj.get("uuid").toString()));
      }
      if (!jsonObj.get("remote_id").isJsonPrimitive()) {
        throw new IllegalArgumentException(String.format("Expected the field `remote_id` to be a primitive type in the JSON string but got `%s`", jsonObj.get("remote_id").toString()));
      }
      if (!jsonObj.get("serviceUuid").isJsonPrimitive()) {
        throw new IllegalArgumentException(String.format("Expected the field `serviceUuid` to be a primitive type in the JSON string but got `%s`", jsonObj.get("serviceUuid").toString()));
      }
      if (!jsonObj.get("secondaryServiceUuid").isJsonPrimitive()) {
        throw new IllegalArgumentException(String.format("Expected the field `secondaryServiceUuid` to be a primitive type in the JSON string but got `%s`", jsonObj.get("secondaryServiceUuid").toString()));
      }
      // ensure the json data is an array
      if (!jsonObj.get("descriptors").isJsonArray()) {
        throw new IllegalArgumentException(String.format("Expected the field `descriptors` to be an array in the JSON string but got `%s`", jsonObj.get("descriptors").toString()));
      }

      JsonArray jsonArraydescriptors = jsonObj.getAsJsonArray("descriptors");
      // validate the required field `descriptors` (array)
      for (int i = 0; i < jsonArraydescriptors.size(); i++) {
        SchemaBluetoothDescriptor.validateJsonObject(jsonArraydescriptors.get(i).getAsJsonObject());
      };
      // validate the required field `properties`
      SchemaCharacteristicProperties.validateJsonObject(jsonObj.getAsJsonObject("properties"));
  }

  public static class CustomTypeAdapterFactory implements TypeAdapterFactory {
    @SuppressWarnings("unchecked")
    @Override
    public <T> TypeAdapter<T> create(Gson gson, TypeToken<T> type) {
       if (!SchemaBluetoothCharacteristic.class.isAssignableFrom(type.getRawType())) {
         return null; // this class only serializes 'SchemaBluetoothCharacteristic' and its subtypes
       }
       final TypeAdapter<JsonElement> elementAdapter = gson.getAdapter(JsonElement.class);
       final TypeAdapter<SchemaBluetoothCharacteristic> thisAdapter
                        = gson.getDelegateAdapter(this, TypeToken.get(SchemaBluetoothCharacteristic.class));

       return (TypeAdapter<T>) new TypeAdapter<SchemaBluetoothCharacteristic>() {
           @Override
           public void write(JsonWriter out, SchemaBluetoothCharacteristic value) throws IOException {
             JsonObject obj = thisAdapter.toJsonTree(value).getAsJsonObject();
             elementAdapter.write(out, obj);
           }

           @Override
           public SchemaBluetoothCharacteristic read(JsonReader in) throws IOException {
             JsonObject jsonObj = elementAdapter.read(in).getAsJsonObject();
             validateJsonObject(jsonObj);
             return thisAdapter.fromJsonTree(jsonObj);
           }

       }.nullSafe();
    }
  }

 /**
  * Create an instance of SchemaBluetoothCharacteristic given an JSON string
  *
  * @param jsonString JSON string
  * @return An instance of SchemaBluetoothCharacteristic
  * @throws IOException if the JSON string is invalid with respect to SchemaBluetoothCharacteristic
  */
  public static SchemaBluetoothCharacteristic fromJson(String jsonString) throws IOException {
    return JSON.getGson().fromJson(jsonString, SchemaBluetoothCharacteristic.class);
  }

 /**
  * Convert an instance of SchemaBluetoothCharacteristic to an JSON string
  *
  * @return JSON string
  */
  public String toJson() {
    return JSON.getGson().toJson(this);
  }
}

